# fluxcd
- Read the fluxcd-map skill before changing anything.
- Changes reach the cluster only through Git: edit, validate offline (`kubectl kustomize`, `flux build ... --dry-run`), leave uncommitted, the user commits, pushes and runs `flux_repo_update`.
- Cluster access is the read-only Kubernetes MCP; never `kubectl apply`, `edit` or `delete`.
- Never read or decrypt `.env`, `secret.yaml`, `*.sops.yaml`, `terraform.tfvars`, the age key or any OpenTofu state. The user encrypts secrets; reference them by name.
- Never run a Makefile target yourself: all of them decrypt `.env`. The user runs `make plan-tf`, the agent reviews the redacted plan, then the user runs `make apply-tf` (auto-approve, so no edits in between).
- Proxmox hosts carry the most critical infrastructure: guide the user, never run commands there.
- Before removing, moving or restoring anything with a PVC, check its backup (`flux-safety-catalog`).
