# Sandbox — OpenShell gateway

Dedicated always-on Proxmox VM running `openshell-gateway`, independent of any in-cluster
OpenShell deployment. The compute driver is selectable via
`openshell_compute_driver` in `ansible/group_vars/sandbox.yml`:

- `podman` (default) — rootless podman; userns reduces the blast radius if the in-sandbox
  jail is bypassed. Recommended for trusted/own code inside the Proxmox VM containment.
- `docker` — rootful docker; simpler, no userns. Leans on the Proxmox VM as the outer
  isolation boundary. Best `--from` UX via `DOCKER_HOST=ssh://`.
- `vm` — libkrun microVMs; strongest isolation (separate guest kernel) but inherits the
  upstream 0.0.47/0.0.48 `/init.krun` egress regression.

Flipping drivers is one line in group_vars + a redeploy; PKI bundle, CLI profile, and the
Terraform stack stay the same.

> Placeholders below (`<vm-ip>`, `<proxmox-node>`, `<age-recipient>`, …) are filled in
> per deployment. The concrete values live in `sandbox/tf/terraform.tfvars` and
> `sandbox/ansible/group_vars/sandbox.yml` — edit those, not this doc.

| | |
|---|---|
| Host / IP / VMID | `<vm-name>` / `<vm-ip>` / `<vmid>` on `<proxmox-node>` (`<datastore>`) |
| Gateway | `0.0.0.0:8080`, mTLS + gateway-minted JWT, driver `vm`, version pinned in group_vars |
| Service user | `openshell` (system user, member of `kvm`), system unit `openshell-gateway.service` |
| CLI profile | e.g. `labvm` → `https://<vm-ip>:8080` (`auth_mode: mtls`) |
| Default sandbox image | set via `openshell_default_image` in group_vars; used when `sandbox create` has no explicit `--from`/image |

## Operate

```bash
make sandbox-init     # one-time backend init
make sandbox-plan     # review
make sandbox-apply    # provision the VM
make sandbox-deploy   # install + configure the gateway (Ansible)
make sandbox-up       # apply + deploy
make sandbox-destroy  # tear down the VM
```

`sandbox-deploy` auto-installs the required Ansible collections
(`community.sops`, `ansible.posix`) from `sandbox/ansible/requirements.yml` before running.

## Secrets

- Proxmox creds + the dedicated `TF_VAR_sandbox_ssh_*_path` keys live in the repo `.env` (SOPS).
  These SSH vars are deliberately distinct from any shared `TF_VAR_ssh_*_path` used by other
  stacks, so the sandbox VM always gets the intended key.
- Gateway PKI/JWT is `sandbox/ansible/files/openshell-pki.sops.yaml` (SOPS, encrypted to your
  age recipient). Generate with `openshell-gateway generate-certs` +
  `sandbox/scripts/build-pki-bundle.sh`, then `sops --encrypt`. The bundle is decrypted at
  deploy time via the `community.sops` Ansible collection.

## One-time setup (operator)

1. Add to `.env` (decrypt, append, re-encrypt) — point at the SSH keypair the VM should use:
   ```
   TF_VAR_sandbox_ssh_public_key_path=<path-to-public-key>
   TF_VAR_sandbox_ssh_private_key_path=<path-to-private-key>
   ```
2. Generate fresh PKI (include the VM's IP and any DNS name you'll reach it by in the server
   SANs), then build + encrypt the bundle:
   ```bash
   openshell-gateway generate-certs --output-dir /tmp/openshell-pki \
     --server-san 127.0.0.1 --server-san localhost \
     --server-san host.containers.internal --server-san host.openshell.internal \
     --server-san <vm-ip> --server-san <vm-name> --server-san <gateway-dns-name>
   sandbox/scripts/build-pki-bundle.sh /tmp/openshell-pki > /tmp/pki.plain.yaml
   sops --encrypt --age <age-recipient> /tmp/pki.plain.yaml \
     > sandbox/ansible/files/openshell-pki.sops.yaml
   shred -u /tmp/pki.plain.yaml
   ```
3. `make sandbox-up`, then register the CLI profile on your workstation. Use `--local` so the
   CLI authenticates with the client cert (mTLS) instead of the cloud/OIDC browser flow, and
   place the client material *before* `status`:
   ```bash
   openshell gateway add https://<vm-ip>:8080 --name <profile> --local
   mkdir -p ~/.config/openshell/gateways/<profile>/mtls
   cp /tmp/openshell-pki/ca.crt         ~/.config/openshell/gateways/<profile>/mtls/ca.crt
   cp /tmp/openshell-pki/client/tls.crt ~/.config/openshell/gateways/<profile>/mtls/tls.crt
   cp /tmp/openshell-pki/client/tls.key ~/.config/openshell/gateways/<profile>/mtls/tls.key
   chmod 600 ~/.config/openshell/gateways/<profile>/mtls/tls.key
   openshell -g <profile> status
   ```

## Known limitations

- **0.0.47 vm-driver egress is broken** (the `/init.krun` ancestor-integrity gate denies all
  egress; regression from 0.0.42). No-egress sandboxes work; policy-allowed egress does not on
  the vm driver. Track upstream; candidate workaround is baking a placeholder `/init.krun` into
  the sandbox image (untested).
- If the gateway misbehaves as a system service, the proven fallback is a rootless `--user`
  systemd service for the `openshell` user with `loginctl enable-linger`.
