# fluxcd

## Workstation access

kubectl logs in through Pocket ID (OIDC); the PC holds no admin credentials.

Set up a new or reinstalled PC:

1. Clone this repo, install `kubectl` and `kubectl-krew`, with SSH access to the nodes (LAN or WireGuard).
2. `make workstation-kubeconfig`: it installs kubelogin (`kubectl krew install oidc-login`) and writes `~/.kube/config`. It reads only the cluster CA from the server. A previous `~/.kube/config` is kept as `config.<timestamp>~`.

Contexts:

- `rke2-device` (the default): prints a Pocket ID URL and a code, to confirm with the passkey on any device. This also works in SSH sessions. Only confirm codes you have just requested yourself.
- `rke2`: browser login on this machine.

Tokens last 1 h. Access comes from the Pocket ID group `k8s_admin`, which is bound to cluster-admin in `kubernetes/apps/kube-system/oidc-rbac`.

Break-glass, for when Pocket ID, Traefik or kube-vip is down: `ssh` to rke2-node-1, then `sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml`.

After a cluster restore, nothing needs to be redone by hand:

- RKE2's OIDC config comes from the Ansible bootstrap.
- The RBAC comes from Flux.
- The Pocket ID client and group come back with Pocket ID's VolSync restore.
- `bootstrap-infra` rewrites the kubeconfig for the new cluster CA.
- `bootstrap.sh` uses a temporary admin kubeconfig until Flux is installed, and deletes it afterwards.
