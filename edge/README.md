# edge — VPS relay + home trust boundary

Public ingress for the homelab without trusting the cloud box:

- The **Hetzner VPS is a stateless dumb pipe.** It holds no TLS keys, no app config,
  no route to the LAN. It forwards raw TCP 443 (HAProxy, PROXY protocol v2) and one
  UDP port into a WireGuard tunnel, and that's all. It can be destroyed and rebuilt
  at any time.
- The **home Proxmox VM `edge-home` is the trust boundary.** It terminates the tunnel
  from the VPS and lets exactly two things through: `9443/tcp` to the cluster's public
  Traefik entrypoint and `51821/udp` to its own admin WireGuard.
- TLS terminates **in the cluster** (Traefik `websecure-pub` entrypoint, `:9443`, on a
  **dedicated public LoadBalancer Service** — not the shared `10.0.0.50` VIP), auth via
  oauth2-proxy.

### Cluster contract

The edge side and the Flux side must agree on two IPs:

| Edge (this dir) | Flux `cluster-settings` | What |
|---|---|---|
| `ingress_ip` in `edge/ansible/group_vars/all.yml` | `EDGE_PUBLIC_LB_IP` | Static IP of the public Traefik LB Service (`externalTrafficPolicy: Local`) |
| `home_vm_ip` in `edge/tf/home` (without `/24`) | `EDGE_HOME_IP` | edge-home's LAN IP; the LB's `loadBalancerSourceRanges` is this `/32` |

`ingress_ip` ships as the placeholder `REPLACE_WITH_PUBLIC_LB_IP`; the playbook's
preflight refuses to run until it is a valid IPv4 address. The port stays `9443`.

Pangolin (`lighthouse/`) is untouched and keeps running until apps are migrated.

## Topology

```
 Internet
    │  443/tcp, 80/tcp            51821/udp (admin clients)
    ▼                                  │
┌──────────────────────── Hetzner VPS (public IP) ────────────────────────┐
│ HAProxy :443 (TCP, send-proxy-v2) ─► 10.99.0.2:9443                     │
│ :80 → 301 https                                                         │
│ nft: udp 51821 DNAT → 10.99.0.2:51821, SNAT → 10.99.0.1                 │
│ wg0 10.99.0.1/24 :51820   peer home: AllowedIPs 10.99.0.2/32            │
│ sshd: listens on 10.99.0.1 only; Hetzner FW + nft block public 22       │
└─────────────────────────────────▲───────────────────────────────────────┘
                                  │ OUTER tunnel (home dials out,
                                  │ keepalive 25; no inbound port at home)
┌─────────────────────────────────┴──── edge-home VM (LAN) ───────────────┐
│ wg-outer 10.99.0.2/24 :51830 ─ nft: allow ONLY                          │
│     tcp 9443 → DNAT <ingress_ip>:9443 (+masq) ──────────┐               │
│     udp 51821 → local wg-inner                          │               │
│     everything else from wg-outer: DROP                 │               │
│ wg-inner 10.99.1.1/24 :51821  (INNER tunnel, carried    │               │
│     inside the outer one)  admin peers 10.99.1.10+      │               │
│     → forward to 10.0.0.0/24 (+masq) ───────────────────┤               │
└─────────────────────────────────────────────────────────┼───────────────┘
                                                          ▼
                         LAN 10.0.0.0/24 ─ public Traefik LB <ingress_ip>:9443
                                           (TLS, oauth2-proxy, apps)

 Admin laptop/phone ── WG (inner, key-authenticated end-to-end with edge-home) ──►
   <vps-ip>:51821 ─ relayed by VPS ─ outer tunnel ─ wg-inner ─ LAN
```

## Blast radius: compromised VPS

An attacker with root on the VPS **can**:

- see and drop/modify traffic metadata (client IPs, SNI, timing, volumes);
- DoS everything public (it is the only ingress path);
- answer `:80` itself — first visits over plain HTTP by browsers that don't have the
  site's HSTS yet can be redirected/phished; only HSTS (ideally preloaded) protects them;
- send arbitrary TCP to `10.99.0.2:9443` → reaches only the public Traefik entrypoint,
  i.e. exactly what the internet can already reach (minus spoofed PROXY headers, so
  don't use the client IP for authorization);
- send UDP to `10.99.0.2:51821` → a WireGuard endpoint that ignores anything not
  authenticated by an admin peer key;
- read the VPS WireGuard private key (it is in `/etc/wireguard`, the Hetzner metadata
  `user_data`, possibly tofu state) and impersonate the VPS towards edge-home — which gives
  it nothing beyond the points above;
- change its own WireGuard config freely — the VPS-side `AllowedIPs` is **not** a
  security control. The controls are on edge-home: wg-outer's peer `AllowedIPs
  10.99.0.1/32` (anything else from the tunnel is dropped by WireGuard) plus the nftables
  ruleset.

It **cannot**:

- obtain a valid certificate for the public hostnames and so read HTTPS — **only because
  of the CAA records** (see below). Without them it could pass HTTP-01 / TLS-ALPN-01
  for any name pointing at it. TLS keys live in the cluster;
- read admin WireGuard traffic (end-to-end between the client and edge-home);
- reach the LAN, the Proxmox hosts, SSH on edge-home, or any other port: edge-home's
  nftables drops (and logs, `edge-wgouter-drop:`) everything from `wg-outer` except
  9443/tcp and 51821/udp, and wg-outer's `AllowedIPs` only admits `10.99.0.1`;
- initiate anything that bypasses edge-home — the home side has no open inbound port
  on the router; the outer tunnel is dialled from home.

## CAA and certificate monitoring

`edge/tf/infra` creates on the **`cloud` label** (`cloud.traunseenet.com`, not the
zone apex, so other zone hosts can keep using HTTP-01):

```
cloud.traunseenet.com. CAA 0 issue     "letsencrypt.org; validationmethods=dns-01[; accounturi=<uri>]"
cloud.traunseenet.com. CAA 0 issuewild "letsencrypt.org; validationmethods=dns-01[; accounturi=<uri>]"
```

A CA looks up CAA at the requested name and climbs to its parents, so this one RRset
covers **every** `*.cloud` name that has no CAA of its own: all names external-dns
creates (no per-host records needed any more), Pangolin's `x.cloud` CNAMEs (a CNAME's
CAA lookup follows to `cloud.traunseenet.com`), and the `*.cloud` wildcard certificate
(its CAA check starts at `cloud.traunseenet.com`).

Since the VPS terminates `:80`/`:443` for these names, a compromised VPS could otherwise
get a certificate via HTTP-01 or TLS-ALPN-01 (from Let's Encrypt or any other CA). With
CAA, only Let's Encrypt may issue, only via DNS-01 (which needs a Cloudflare token the
VPS never sees).

Everything issuing for `*.cloud` today uses DNS-01 (checked when the CAA moved here):
the cluster's only ACME issuer `ClusterIssuer letsencrypt-prod` (`dns01.cloudflare`) and
Pangolin's Traefik (`lighthouse/ansible/templates/traefik_config.yml.j2`,
`dnsChallenge: cloudflare`). Anything new under `*.cloud` **must** use DNS-01 too.

Optionally pin the cluster's ACME account (`accounturi`) — **but not while
lighthouse/Pangolin still serves `*.cloud` names** (`cloud.traunseenet.com` itself and
its `x.cloud` CNAMEs): Pangolin has its own Let's Encrypt account and its renewals would
fail. Once lighthouse is gone, get the URI with

```sh
kubectl get clusterissuer letsencrypt-prod -o jsonpath='{.status.acme.uri}'
```

and set `acme_account_uri` (e.g. `TF_VAR_acme_account_uri` or `terraform.tfvars`), then
`make edge-infra-apply`. If cert-manager's ACME account is ever re-registered, the URI
changes and issuance for `*.cloud` fails until it is updated.

Notes:
- Check what is actually published: `dig CAA oauth.cloud.traunseenet.com` (answers with
  the `cloud` RRset). If Cloudflare adds CAA records for its own CAs (Universal SSL),
  those CAs are allowed too — verify.
- **Monitor Certificate Transparency** for the zone, e.g. a crt.sh search
  (`https://crt.sh/?q=%25.traunseenet.com`) or a certspotter/SSLMate watch, so any
  unexpected certificate is noticed.

## Public DNS (external-dns)

Public A records are created by a second external-dns instance,
`kubernetes/apps/networking/external-dns/external-dns-public` (Flux Kustomization
`externaldns-public-app`), from **HTTPRoutes attached to Gateway
`networking/traefik-public`** — nothing else:

| Setting | Effect |
|---|---|
| `--source=gateway-httproute --gateway-name=traefik-public --gateway-namespace=networking` | only routes on the public Gateway |
| Gateway annotation `external-dns.alpha.kubernetes.io/target: "195.201.24.122"` | record content = edge VPS IP (the Gateway's status address is the shared LAN VIP). **Update it if the VPS is rebuilt with a new IP** (`hcloud_server.edge`). |
| `--regex-domain-filter=^([a-z0-9-]+\.cloud\.)?traunseenet\.com$` | only `<one-label>.cloud.traunseenet.com` (never `cloud.traunseenet.com` itself = Pangolin's A record, never wildcards). A plain `--domain-filter=cloud.traunseenet.com` does not work with Cloudflare: the zone `traunseenet.com` itself is matched against the filter and would be skipped. |
| `--policy=upsert-only`, `--registry=txt --txt-owner-id=edge-public --txt-prefix=edge-public-` | never deletes; only updates records it owns (TXT `edge-public-a-<host>.cloud…` with `external-dns/owner=edge-public`). Unowned records — lighthouse's Pangolin CNAMEs, anything created by hand or tofu — are skipped, never overwritten. The TXT sits at a different name than the record, so it can't clash with a CNAME. |
| `--no-cloudflare-proxied` | DNS-only (grey cloud): the edge needs TLS passthrough. |

Because the policy is upsert-only, **removing a public route does not remove its
record** — delete the A record and its `edge-public-a-<host>` TXT in Cloudflare by hand
(or switch to `--policy=sync` once trusted; deletion is still limited to owned records).

The internal (Technitium) instance runs with `--gateway-name=traefik
--gateway-namespace=networking`, so it ignores `traefik-public` and its target
annotation: a route attached to **both** Gateways resolves to `10.0.0.50` internally and
to the VPS publicly (split horizon). A route attached **only** to `traefik-public` gets
no internal record — attach LAN-reachable apps to both Gateways.

### Cloudflare API token

dash.cloudflare.com → *My Profile* → *API Tokens* → *Create Token* → *Create Custom
Token*:

- **Permissions:** `Zone` · `DNS` · `Edit` **and** `Zone` · `Zone` · `Read`
- **Zone Resources:** `Include` · `Specific zone` · `traunseenet.com` (only this zone)
- optional: *Client IP Address Filtering* = your WAN IP
- *Continue to summary* → *Create Token*, copy it once.

Use a new token just for this instance (not cert-manager's, not tofu's). Then:

```sh
cd kubernetes/apps/networking/external-dns/external-dns-public/app
cp secret.yaml.example secret.yaml        # paste the token as CF_API_TOKEN
sops --encrypt --age age1q3mu6g0l3kr7spszks69yqrvlxvlgfrqgw9r00qqt8cj9xpjd9mqdkd7um --encrypted-regex '^(data|stringData)$' --in-place secret.yaml
```

and list `secret.yaml` in that directory's `kustomization.yaml` (commented line).

### Cutover to external-dns (one-off)

Before this change `edge/tf/infra` owned the A records (`public_hostnames`) and per-host
CAA. Order (zero DNS gap — a gap would be cached as NXDOMAIN for up to 30 min, the
zone's SOA minimum is 1800 s):

0. **Ship the Technitium filter before the Gateway annotation.** The internal instance
   only ignores the target annotation once it runs with `--gateway-name=traefik`. Push
   `external-dns/app/deployment.yaml` first and wait until `externaldns-app` is applied
   (`flux get ks externaldns-app`), then push `gateway-public.yaml`. Otherwise
   `oauth.cloud` gets the VPS IP added in internal DNS for a few minutes. Check
   afterwards: `dig +short @10.0.0.99 oauth.cloud.traunseenet.com` → only `10.0.0.50`.
1. **Pre-create the ownership TXT** for the existing record (Cloudflare → DNS → Add
   record, DNS only):
   - Type `TXT`, Name `edge-public-a-oauth.cloud`, TTL Auto, Content
     `"heritage=external-dns,external-dns/owner=edge-public,external-dns/resource=httproute/auth/oauth2-proxy"`

   This makes external-dns treat the existing `oauth.cloud` A record as its own (same
   content → no change). Without it, external-dns logs an owner mismatch and leaves the
   record alone — still working, just unmanaged.
2. **Create + encrypt the token** (above), list `secret.yaml`, set `suspend: false` in
   `external-dns-public/ks.yaml`, push. Check:
   `kubectl -n networking logs deploy/external-dns-public` — no errors; `All records are
   already up to date` (or one update of `oauth.cloud`, which is fine).
3. **`make edge-infra-apply`.** The plan must show: `cloudflare_dns_record.public` →
   *will no longer be managed* (the `removed` block, **not destroyed**), per-host
   `cloudflare_dns_record.caa[...]` × 4 destroyed, `cloudflare_dns_record.caa_cloud[...]`
   × 2 created. Nothing under `cloudflare_dns_record.public` may say *destroy*.
   (The old per-host CAA and the new `cloud` CAA are swapped in the same apply — for a
   few seconds `oauth.cloud` may have no CAA. Acceptable; run it when nothing is
   attacking the VPS.)
4. **Delete the orphan** `whoami.cloud` A record (+ its CAA, if still there) in the
   Cloudflare UI — the canary is gone and nothing owns that record any more.
5. Verify: `dig +short @1.1.1.1 oauth.cloud.traunseenet.com` → `195.201.24.122`;
   `dig +short @1.1.1.1 TXT edge-public-a-oauth.cloud.traunseenet.com`;
   `dig CAA oauth.cloud.traunseenet.com @1.1.1.1` → the two `cloud` records.

Skipping step 1 is safe but then `oauth.cloud` stays unmanaged; to hand it over later,
create the TXT (step 1) at any time — or delete the A record and let external-dns
recreate it within a minute (short gap, see above).

## Layout

| Path | What |
|---|---|
| `edge/tf/infra/` | VPS, Hetzner firewall, CAA on `cloud.traunseenet.com`, wg0 bootstrap via cloud-init (OpenTofu, state key `edge/infra`) |
| `edge/tf/home/` | `edge-home` Proxmox VM; reads `server_ip` from the infra state and renders `edge/ansible/inventory.ini` (state key `edge/home`) |
| `edge/ansible/` | Config for both hosts: HAProxy/nft/wg on the VPS, wg-outer/wg-inner/nft on edge-home, patching + sshd hardening on both. Own `ansible.cfg` (strict host keys, `known_hosts`) |
| `kubernetes/apps/networking/traefik/…` | Public Traefik entrypoint `websecure-pub` (:9443, PROXY protocol), Gateway `traefik-public` (+ external-dns target annotation) |
| `kubernetes/apps/auth/oauth2-proxy/` | oauth2-proxy (`oauth.cloud`, forward-auth for public apps) |
| `kubernetes/apps/networking/external-dns/external-dns-public/` | external-dns → Cloudflare for routes on `traefik-public` (see Public DNS) |
| `kubernetes/apps/kube-system/admission-policies/` | ValidatingAdmissionPolicy `httproute-public-edge` (forward-auth required on public routes) |

## Prerequisites

1. **SSH keypair** dedicated to edge (Hetzner rejects duplicates of lighthouse's
   `~/.ssh/hetzner.pub` in the same project):
   ```sh
   ssh-keygen -t ed25519 -f ~/.ssh/edge -C edge
   ```
2. **WireGuard keypairs** — generate three (VPS wg0, home wg-outer, home wg-inner),
   plus one per admin device. Do it in `$XDG_RUNTIME_DIR` (tmpfs, never hits disk), so
   nothing needs shredding (`shred` is meaningless on btrfs/CoW and SSDs anyway):
   ```sh
   cd "$XDG_RUNTIME_DIR" && umask 077
   for k in vps home-outer home-inner; do wg genkey | tee $k.priv | wg pubkey > $k.pub; done
   ```
3. **Private keys → SOPS `.env`**: open `sops .env` and paste the `*.priv` contents
   directly, exactly these names:
   - `TF_VAR_edge_wg_vps_private_key` — `vps.priv` (used by tofu cloud-init *and* Ansible)
   - `EDGE_WG_HOME_OUTER_PRIVATE_KEY` — `home-outer.priv`
   - `EDGE_WG_HOME_INNER_PRIVATE_KEY` — `home-inner.priv`

   Then `rm "$XDG_RUNTIME_DIR"/*.priv` (tmpfs; gone at logout/reboot anyway).
4. **Public keys** (non-secret):
   - `edge/ansible/group_vars/all.yml`: `wg_vps_public_key`, `wg_home_outer_public_key`,
     `wg_home_inner_public_key`, and `wg_admin_peers` (one entry per admin device).
   - `edge_wg_home_public_key` (= `home-outer.pub`) for `edge/tf/infra`: either
     `edge/tf/infra/terraform.tfvars` or `TF_VAR_edge_wg_home_public_key` in `.env`.
5. Existing `.env` already provides Hetzner/Cloudflare tokens (`TF_VAR_hetzner_token`,
   `TF_VAR_cloudflare_token`, `TF_VAR_cloudflare_zone_domain`), Proxmox creds
   (`TF_VAR_proxmox_*`) and the S3 state backend credentials.

> **Secret in user_data:** the VPS WireGuard private key is rendered into the server's
> cloud-init `user_data`, so it is in Hetzner's server metadata (on the VPS, nft lets
> only root reach `169.254.169.254`). Whether the `edge/infra` tofu state holds the
> plaintext `user_data` or only a hash depends on the provider — check it yourself with
> `tofu state show hcloud_server.edge` and treat the state as secret either way.
> `user_data` is in `ignore_changes`: that freezes *every* cloud-init value at server
> creation, and Ansible is the source of truth afterwards. See **Key rotation**.

## Host keys

`make edge-deploy` uses `edge/ansible/ansible.cfg`: `StrictHostKeyChecking=yes` against
`edge/ansible/known_hosts` only (the ProxyCommand hop to the VPS uses the same file). No
trust-on-first-use: pin both host keys **out-of-band** before deploying. Host public keys
are not secret; commit `known_hosts` (format: `known_hosts.example`). Run Ansible from
the repo root (the path is relative; anywhere else ssh fails closed).

- **edge-home** — read `/etc/ssh/ssh_host_ed25519_key.pub` without trusting the network:
  Proxmox console (noVNC, log in with the console password), or, as qemu-guest-agent is
  enabled, from the Proxmox host: `qm guest exec <vmid> -- cat /etc/ssh/ssh_host_ed25519_key.pub`
  (the agent is installed by Ansible; on the very first run use the console unless the
  template already ships it). Add it as `<home_vm_ip> ssh-ed25519 AAAA…`.
- **VPS** — from the Hetzner web console: `cat /etc/ssh/ssh_host_ed25519_key.pub`, add as
  `10.99.0.1 ssh-ed25519 AAAA…`. Alternatively, once edge-home is pinned and wg-outer is
  up, `ssh edge-home ssh-keyscan -t ed25519 10.99.0.1` runs over the WireGuard tunnel,
  which authenticates the VPS by its WG key — acceptable, but weaker than the console
  (anyone with the VPS WG private key could answer).
- `ssh-keyscan` over an untrusted path (e.g. straight at a fresh IP) is exactly the MITM
  window strict checking is meant to close — only use it on a path you trust (your own
  LAN segment for edge-home), and compare the fingerprint (`ssh-keygen -lf`) with the
  console if at all possible.
- Rebuilding a host changes its key: replace the line, never switch to `accept-new`.

## Bootstrap

Order matters: **infra → home → deploy** (home reads the VPS IP from the infra state).

```sh
# 1. VPS, firewall, CAA on cloud.traunseenet.com (A records come from external-dns)
make edge-infra-init edge-infra-apply

# 2. home VM — set the two required vars first, e.g. edge/tf/home/terraform.tfvars:
#      home_vm_ip   = "10.0.0.x/24"
#      proxmox_node = "pve-01"
#    (edge_home_storage/edge_home_template_id/edge_home_template_node default to pve-01's local-zfs + template 999;
#     override them for another node)
make edge-home-init edge-home-apply     # also renders edge/ansible/inventory.ini

# 3. set ingress_ip (Cluster contract) and pin host keys (Host keys), then configure
#    both hosts. First run: the VPS key can only be scanned once wg-outer is up, so
#    either pin it from the Hetzner console first, or run the home play alone first
#    (ANSIBLE_CONFIG=edge/ansible/ansible.cfg ansible-playbook --limit edge_home ...).
make edge-deploy
```

`make edge-up` runs apply → apply → deploy in one go once everything is initialised.

**First deploy:** the `edge_home` play runs first and brings up `wg-outer`, which dials
the VPS (whose `wg0` is already up from cloud-init). Only then is `10.99.0.1` reachable,
and the `edge_vps` play connects through edge-home (ProxyCommand/jump via the home VM's
LAN IP, same `~/.ssh/edge` key). There is no public SSH on the VPS at any point; if the
outer tunnel is broken, use the Hetzner web console.

Verify: `curl -I https://oauth.cloud.traunseenet.com/ping` (once external-dns-public has
published the record, see Public DNS).

## Hardening applied by Ansible

- **Fail closed:** `wg-quick@wg-outer`/`wg-inner` (home) and `wg-quick@wg0` (VPS) have a
  systemd drop-in `Requires=nftables.service` + `After=nftables.service`, and each wg
  config has `PreUp = nft list table inet edge >/dev/null`. If the ruleset fails to load
  at boot, the tunnels stay down (on the VPS that also means sshd on `10.99.0.1` is
  unreachable → Hetzner console). nftables changes are applied with `reload` (atomic
  `nft -f`, file starts with `flush ruleset`), never `restart`.
- **Patching:** unattended-upgrades (Debian-Security origin) with automatic reboot at
  04:30 (edge-home) / 05:15 (VPS) — distinct so both tunnel ends are never down at
  once. Time sync via systemd-timesyncd (or chrony if present).
- **sshd** (both): `PasswordAuthentication no`, `KbdInteractiveAuthentication no`,
  `PermitRootLogin no`, `AllowUsers <ansible_user>`; on the VPS also
  `ListenAddress 10.99.0.1`. The drop-in is syntax-checked before install, then the
  full config is checked with `sshd -t`; on failure the previous drop-in is restored.
  edge-home's cloud-init password (`random_password` in `edge/tf/home`) is for the
  Proxmox console only.
- **DoS limits (VPS):** HAProxy `maxconn 4096`; `:443` only forwards connections that
  send a TLS ClientHello within 5s; per-source limits (443: 100 concurrent / 200 per
  10s, 80: 20 / 100); 60s client/server idle timeouts until the TLS tunnel is
  established, then `timeout tunnel 1h`. nftables rate-limits new relayed udp/51821
  flows per source (20/s, burst 50); `nf_conntrack_max` raised to 262144.
- **Metadata:** on the VPS only root may reach `169.254.169.254` (cloud-init user_data).

## Admin client (laptop / phone)

Add the device's public key to `wg_admin_peers` (IP `10.99.1.10+`), `make edge-deploy`,
then on the device:

```ini
[Interface]
PrivateKey = <device private key>
Address    = 10.99.1.10/32
DNS        = 10.0.0.99
# Inner WG runs inside the outer WG (VPS <-> home): two layers of ~80 B overhead.
# 1500 - 80 (outer) - 80 (inner) = 1340.
MTU        = 1340

[Peer]
# edge-home wg-inner (NOT the VPS key)
PublicKey           = <wg_home_inner_public_key>
Endpoint            = <vps-ip>:51821
AllowedIPs          = 10.99.1.0/24, 10.0.0.0/24
PersistentKeepalive = 25
```

The VPS only relays the UDP packets; the handshake is with edge-home, so the VPS can't
read or inject admin traffic.

## Key rotation

Rotating the **outer** keys is the dangerous part: Ansible reaches the VPS *through*
wg-outer, so whichever side switches first cuts the path the other side's change needs.
`ignore_changes = [user_data]` means tofu never pushes new keys; Ansible does. The
pattern: stage the VPS change on disk, arm a **deferred** restart on the VPS, switch
home, let the timer switch the VPS.

`deploy-home` below means:
`set -a; eval "$(sops --decrypt .env)"; set +a; ANSIBLE_CONFIG=edge/ansible/ansible.cfg ansible-playbook -i edge/ansible/inventory.ini edge/ansible/site.yml --limit edge_home`
(from the repo root).

**VPS wg0 key** (`TF_VAR_edge_wg_vps_private_key` / `wg_vps_public_key`):

1. Generate the new pair (Prerequisites), put the private key in `.env` and the public
   key in `wg_vps_public_key`.
2. SSH to the VPS (tunnel still up), `sudoedit /etc/wireguard/wg0.conf` → new
   `PrivateKey` (not applied yet), then
   `sudo systemd-run --on-active=90 systemctl restart wg-quick@wg0`.
3. Immediately `deploy-home` (edge-home now expects the new VPS key; the tunnel is down
   until the timer fires).
4. After the timer: tunnel is back; run a full `make edge-deploy` to converge.

**Home wg-outer key** (`EDGE_WG_HOME_OUTER_PRIVATE_KEY` / `wg_home_outer_public_key` /
`TF_VAR_edge_wg_home_public_key`): same pattern, mirrored.

1. New pair; private key in `.env`, public key in `wg_home_outer_public_key` and
   `TF_VAR_edge_wg_home_public_key` (only used if the VPS is ever rebuilt).
2. On the VPS: `sudoedit /etc/wireguard/wg0.conf` → `[Peer] PublicKey` = new home
   public key, then `sudo systemd-run --on-active=90 systemctl restart wg-quick@wg0`.
3. Immediately `deploy-home`; after the timer, full `make edge-deploy`.

If anything goes wrong, the **Hetzner web console** is the way back in (fix
`/etc/wireguard/wg0.conf`, `systemctl restart wg-quick@wg0`).

**wg-inner / admin peers:** no lock-out risk (the outer tunnel is unaffected); update
`.env`/`group_vars`, `make edge-deploy`, then the client configs.

The bootstrap copy of the VPS key in `user_data` (Hetzner metadata, maybe tofu state) is
never updated; after a rotation it is a stale, useless key. Rebuild the server to get rid
of it.

## Exposing an app publicly

Attach an `HTTPRoute` to the public Gateway **with oauth2-proxy forward-auth on every
rule** — DNS follows automatically (external-dns-public creates
`<name>.cloud.traunseenet.com` A → VPS within ~1 min):

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: myapp
  namespace: apps          # namespace must carry edge.traunseenet.com/public: "true"
spec:
  parentRefs:
    - name: traefik         # internal (LAN) — keep it, see split horizon above
      namespace: networking
      sectionName: websecure-cloud
    - name: traefik-public
      namespace: networking
      sectionName: websecure-public
  hostnames:
    - myapp.cloud.traunseenet.com
  rules:
    - filters:
        - type: ExtensionRef
          extensionRef:
            group: traefik.io
            kind: Middleware
            name: oauth2-forward-auth   # any name starting with oauth2-forward-auth
      backendRefs:
        - name: myapp
          port: 80
```

- Hostnames must be a single label under `*.cloud.traunseenet.com` (the listener's
  wildcard cert, and the external-dns filter).
- The ValidatingAdmissionPolicy `httproute-public-edge` **rejects** any HTTPRoute that
  names `traefik-public` unless every rule has such an `ExtensionRef` filter
  (rule-level, not on a backendRef) — or the route is deliberately public and says why:
  ```yaml
  metadata:
    annotations:
      edge.traunseenet.com/public-unauthenticated: "<non-empty reason>"
  ```
  (oauth2-proxy's own route uses this). It also rejects a `*cloudflare-proxied`
  annotation other than `"false"` on public routes.
- Don't reuse a hostname that lighthouse/Pangolin already has (its `x.cloud` CNAMEs):
  external-dns will not touch an unowned record, so the name keeps pointing at Pangolin.
  Remove it from the newt blueprint (lighthouse tofu) first.
- Removing the route does **not** remove the record (upsert-only) — delete it by hand.

Nothing changes on the VPS or edge-home — they forward all of 443 blindly.

## Out of scope (phases 2/3)

- CrowdSec in the cluster (Traefik bouncer)
- GeoIP filtering
- Migrating apps off Pangolin and removing `lighthouse/`
