---
name: fluxcd-map
description: Layout, commands and rules of the fluxcd homelab repo (RKE2 cluster on Proxmox, Flux, edge VPS). Use before changing, building, validating or deploying anything in this repo.
---
## Layout
- `kubernetes/flux/`: Flux entry. `apps.yaml` is Kustomization `cluster-apps` (path `./kubernetes/apps`, prune, SOPS decryption patched into every child Kustomization). `config/` holds `cluster`, `repositories/` the Git and Helm sources, `vars/` the `cluster-settings` ConfigMap.
- `kubernetes/apps/<namespace>/<app>/<app>/`: `ks.yaml` (Kustomizations `<app>-app`, often `<app>-backup`, `<app>-addons`), `app/` manifests, `backup/` VolSync. Each namespace dir lists its apps in `kustomization.yaml`. Namespaces: ai, apps, auth, kube-system, networking, observability, security (crowdsec), storage; namespace objects in `kubernetes/apps/namespaces/`.
- `kubernetes/bootstrap/flux/`: one-time bootstrap (age key, SOPS encrypted).
- `cluster/tf/`: OpenTofu (bpg/proxmox provider, S3 state backend) for the RKE2 node VMs; renders `cluster/ansible/inventory.ini`.
- `cluster/ansible/infra/{bootstrap,maintenance}/`: node bootstrap and maintenance playbooks, run through Makefile targets.
- `edge/tf/{infra,home}/`, `edge/ansible/`: public edge VPS and the home edge VM; see `edge/README.md`.
- Proxmox hosts and guests: `proxmox.md` next to this file.
## Commands
- render: `kubectl kustomize <dir>`; Flux dry run: `flux build kustomization <name> --path <dir> --kustomization-file <ks.yaml> --dry-run`. Report exit status only, never paste rendered Secrets.
- reconcile (the user runs it): fish function `flux_repo_update` (source `fluxcd-kubernetes`, then Kustomizations `cluster` and `cluster-apps`).
- no lint, kubeconform, pre-commit or tests exist in this repo.
- OpenTofu and Ansible run only through Makefile targets that load `.env` via SOPS: the user runs them. Node VMs: `make plan-tf`, paste the plan redacted, then `make apply-tf`.
## Conventions
- Conventional commits with scope = app: `feat(falco): ...`, `fix(open-webui): ...`, `chore(vault): ...`. Work on main; the user commits and pushes.
- New app: copy an existing app's `<app>/<app>/` tree (fin is a clean example), add it to the namespace `kustomization.yaml`, `ks.yaml` with `dependsOn`, `healthChecks`, `targetNamespace`, interval/retryInterval/timeout `15m`, sourceRef `fluxcd-kubernetes`.
- Images: through Harbor, pinned `tag@sha256`, never `:latest`. Upstream images: Renovate (`renovate.json`, `pinDigests`) opens bump PRs. Own images (fin, track, mdmem, under Harbor `library/`) the same way; the user bumps a pin by hand when impatient (their CI prints `tag@digest`).
- Secrets: `secret.yaml` per app, SOPS encrypted by the user, or ExternalSecrets from Vault. Reference secrets by name only.
## Never
- Read or decrypt `.env`, any `secret.yaml` or `*.sops.yaml`, `terraform.tfvars`, the age key, the OpenTofu state or `inventory.ini`. No `sops -d`, no Makefile target (all of them decrypt `.env`).
- `make destroy-tf`, `bootstrap-infra`, or `apply-tf` without a fresh reviewed `make plan-tf`: `apply-tf` re-plans and applies with `-auto-approve`, so nothing may change between the reviewed plan and the apply (`proxmox-vm-lifecycle`).
- `kubectl apply`/`edit` against the cluster: Flux owns the state. Access is the read-only Kubernetes MCP.
- Commit decrypted copies (`.decrypted~*` is ignored for that reason).
## Gotchas
- Every Kustomization has a 15m retryInterval: a failed dependency stalls its dependents for 15m. Reconcile instead of waiting.
- `prune: true` everywhere: removing or moving a path deletes the objects; PVC-backed apps need a VolSync backup first (`flux-safety-catalog`).
- VolSync restore: deleting a PVC replays the ReplicationDestination's frozen `latestImage`. Bump the trigger first (`flux-restore-volsync`).
- Calico evaluates egress NetworkPolicies after DNAT: target in-cluster services with `podSelector`, never an `ipBlock` of a Service IP.
- `kube-vip` `loadBalancerIP: "0.0.0.0"` means DHCP mode; pin addresses with the `kube-vip.io/loadbalancerIPs` annotation.
- Nodes must resolve only through the internal DNS server (split horizon); a public resolver breaks every Harbor pull.
- Kata runtime works only on nodes 1 and 3.
