# Sandbox — OpenShell host

Proxmox VM (Debian 13) that runs `openshell-gateway` for the LAN and doubles as a dev host
with `pi` + `claude` installed for the `ansible` user.

Driver via `openshell_compute_driver` in `ansible/group_vars/sandbox.yml`:
`podman` (default, rootless) · `docker` (rootful) · `vm` (libkrun; egress regression fixed
upstream but not yet in a published release — see *Known limitations*).

> Concrete values live in `tf/terraform.tfvars` and `ansible/group_vars/sandbox.yml`.

| | |
|---|---|
| Gateway | `0.0.0.0:8080`, mTLS + gateway-minted JWT, version `openshell_version` |
| Service | `openshell-gateway.service` as system user `openshell` |
| Host CLIs | `pi` + `claude` in `/usr/local/bin` (Node 22 via NodeSource), versions pinned in group_vars |
| CLI profile | e.g. `labvm` → `https://<vm-ip>:8080` (mTLS) |
| Default sandbox image | `openshell_default_image` in group_vars |

## Operate

```bash
make sandbox-init     # one-time backend init
make sandbox-plan     # review
make sandbox-apply    # provision the VM
make sandbox-deploy   # Ansible: gateway + host tooling
make sandbox-up       # apply + deploy
make sandbox-destroy  # tear down
```

`sandbox-deploy` auto-installs the Ansible collections from `ansible/requirements.yml`.

## Secrets

- `TF_VAR_sandbox_ssh_*_path` in the repo `.env` (SOPS) — deliberately distinct from any
  shared `TF_VAR_ssh_*` used elsewhere.
- `ansible/files/openshell-pki.sops.yaml` — gateway PKI/JWT bundle.
- (Optional) `ansible/files/host-env.sops.yaml` — host env vars (`data:` map,
  `--encrypted-regex '^(data|stringData)$'`); rendered to `/etc/profile.d/host-env.sh`
  (0640 root:ansible). Absent file = no-op.

## One-time setup

1. Add SSH key paths to `.env`:
   ```
   TF_VAR_sandbox_ssh_public_key_path=<path>
   TF_VAR_sandbox_ssh_private_key_path=<path>
   ```
2. Generate + encrypt the gateway PKI:
   ```bash
   openshell-gateway generate-certs --output-dir /tmp/openshell-pki \
     --server-san 127.0.0.1 --server-san localhost \
     --server-san host.containers.internal --server-san host.openshell.internal \
     --server-san <vm-ip> --server-san <vm-name> --server-san <gateway-dns-name>
   scripts/build-pki-bundle.sh /tmp/openshell-pki > /tmp/pki.plain.yaml
   sops --encrypt --age <age-recipient> /tmp/pki.plain.yaml \
     > ansible/files/openshell-pki.sops.yaml
   shred -u /tmp/pki.plain.yaml
   ```
3. (Optional) Encrypt host env vars — open `$EDITOR`, paste plaintext, then:
   ```bash
   sops --encrypt --age <age-recipient> --encrypted-regex '^(data|stringData)$' \
     <tmpfile> > ansible/files/host-env.sops.yaml
   ```
   Plaintext shape:
   ```yaml
   data:
     ANTHROPIC_API_KEY: sk-ant-...
     GITEA_TOKEN: glpat-...
   ```
4. (Optional) Pre-install Pi extensions via `openshell_pi_extensions` in group_vars (entries
   fed verbatim to `pi install`; public Gitea = `git:host/owner/repo`).
5. `make sandbox-up`, then on your workstation:
   ```bash
   openshell gateway add https://<vm-ip>:8080 --name <profile> --local
   mkdir -p ~/.config/openshell/gateways/<profile>/mtls
   cp /tmp/openshell-pki/ca.crt         ~/.config/openshell/gateways/<profile>/mtls/ca.crt
   cp /tmp/openshell-pki/client/tls.crt ~/.config/openshell/gateways/<profile>/mtls/tls.crt
   cp /tmp/openshell-pki/client/tls.key ~/.config/openshell/gateways/<profile>/mtls/tls.key
   chmod 600 ~/.config/openshell/gateways/<profile>/mtls/tls.key
   openshell -g <profile> status
   ```

`ssh ansible@<vm-ip>` afterwards gets you `pi` + `claude` (interactive `claude login` on
first use), with any Pi extensions in `~/.pi/agent/` and host env vars from `host-env.sh`.

## Known limitations

- **vm-driver egress broken in ≤0.0.83** — regression introduced by PR #1263 (ext4-root-disk
  boot layering placed `/init.krun` above the supervisor, breaking outbound guest traffic;
  issue #1998). Fixed upstream by PR #2299 ("run sandbox supervisor as guest pid 1"), which
  ships in v0.0.84 (tag exists, release not published as of 2026-07-16). Reason podman is the
  default for now. To switch once 0.0.84 is out:
  ```yaml
  openshell_compute_driver: vm
  openshell_version: "0.0.84"
  ```
  The vm host prerequisites (nftables, e2fsprogs, kvm group) are already handled by
  `tasks/driver-vm.yml` and will run automatically when the driver is set to `vm`.
- Gateway misbehaving as a system service: fallback is a rootless `--user` unit for the
  `openshell` user with `loginctl enable-linger`.
