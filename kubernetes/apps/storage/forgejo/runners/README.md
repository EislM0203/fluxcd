# Forgejo Actions runners (ephemeral, queue-driven)

Runner pool for `git.cloud.traunseenet.com` (Forgejo 16, `storage/forgejo`), in its
own namespace `forgejo-runners`. Adapted from an existing setup for Forgejo 15+.

There is no idle runner. `forgejo-runner-autoscaler` polls Forgejo's job queue and
starts **one Kubernetes Job per waiting workflow job**; that pod registers itself as
an *ephemeral* runner, runs exactly that one job (`forgejo-runner one-job --handle`)
and exits. Nothing runs when nothing is queued.

```
Forgejo queue ──poll──▶ autoscaler ──▶ Job (runner + DinD sidecar) ──▶ exits
                           └── registers single-use runner ──┘  Forgejo deletes the
                                                               runner after the job
```

| File | What it is |
|---|---|
| `app/deployment-autoscaler.yaml` | Poller/dispatcher, 1 replica, `Recreate`. Tuning knobs are its env vars. |
| `app/configmap-autoscaler.yaml` | `autoscaler.sh` (incl. the runner Job template) and `labels.txt` (workflow label → image). |
| `app/configmap-runner.yaml` | `config.yaml` for every runner pod (cache, `network: host`, DinD env). |
| `app/rbac.yaml` | Autoscaler SA/Role (jobs + secrets in this namespace only); permission-less SA for runner pods. |
| `app/networkpolicy.yaml` | Runner pods: no ingress; egress only DNS, Forgejo, Traefik, internet (no LAN). |

## Setup (token — done by hand, not in git)

Repos live in two orgs: `traunseenet` (public org; repos public or private per repo)
and `traunseenet-lab` (private org, internal). The autoscaler serves **org-level
runners** for both (`RUNNERS_API`, space-separated) — the tightest scope that fits
(Forgejo actions security docs). Repos outside these orgs get no CI.

Token: bot `ci-runner-bot`, **not** a site admin, member of the `Owners` team of
both orgs, token scope **`write:organization` only**. Not admin → no `?sudo=`
impersonation, no admin API (403); no repository scope → no repo contents.

```sh
kubectl -n storage exec deploy/forgejo -- forgejo admin user create \
  --username ci-runner-bot --email ci-runner-bot@noreply.local --random-password --must-change-password=false
# add ci-runner-bot to the Owners team of each org (UI or PUT /api/v1/teams/<id>/members/ci-runner-bot)
kubectl -n storage exec deploy/forgejo -- forgejo admin user generate-access-token \
  --username ci-runner-bot --token-name runner-autoscaler --scopes write:organization --raw
```

(`generate-access-token` prints a log line after the token; take the first line.)
Store it in Vault at `storage/forgejo-runners`, key `FORGEJO_API_TOKEN`;
`app/externalsecret.yaml` syncs it into Secret `forgejo-runner-autoscaler-token`. There is no reloader:
after rotating, `kubectl -n forgejo-runners rollout restart deploy/forgejo-runner-autoscaler`.

A new org gets CI by adding the bot to its Owners team and appending
`/api/v1/orgs/<org>/actions/runners` to `RUNNERS_API`. Other levels (same API):
`/api/v1/user/actions/runners` (`write:user`; if that user is admin, `?sudo=`
works, so it is not least privilege) and `/api/v1/admin/actions/runners` (`write:admin`).

## Workflow labels

`runs-on` labels must **all** be mapped in `labels.txt` (`label=docker://image`),
otherwise the job is left queued and the reason is logged. `ubuntu-latest` maps to
`node:22-bookworm` because GitHub-style JS actions (`actions/checkout@v4`) need node.
Images go through Harbor's pull-through cache (`harbor.cloud.traunseenet.com/docker.io/...`);
dockerd `registry-mirrors` can't be used with Harbor's project-namespaced paths.
`code.forgejo.org/forgejo/runner` is pulled directly (no Harbor proxy project for it).

## Security

- The API token (non-admin bot, `write:organization`) lives only in the autoscaler pod, whose NetworkPolicy allows
  egress only to Forgejo, DNS and the Kubernetes API. Runner pods get the
  single-use token of their own job and a ServiceAccount without permissions or token.
- The DinD sidecar is **privileged**, and jobs get `DOCKER_HOST` + the TLS client
  certs (so `docker build` works). A workflow can therefore take over the node its
  pod runs on. Acceptable here because only members of `forgejo_users` (Pocket ID)
  have accounts and can trigger workflows; never point untrusted repos/forks at it.
  To hide the daemon from jobs, drop the three `runner.envs` entries and the
  `options`/`valid_volumes` lines in `configmap-runner.yaml` (no image builds then).
- `app/networkpolicy.yaml` keeps runner pods out of the LAN even so (and pins the
  autoscaler to Forgejo + the API server; update its ipBlock if the control plane changes).

### Experimental: user namespaces (`HOST_USERS=false`)

Sets `hostUsers: false` on runner pods (UserNamespacesSupport is beta and on by
default since K8s 1.33; works on these nodes: kernel 6.8, containerd 2.1.5, all
volumes are emptyDir/configMap/secret, which are idmappable). "Privileged" DinD is
then only root inside the pod's user namespace. dockerd cannot manage the pod
netns (owned by the host userns), so it starts with `--bridge=none --iptables=false`;
jobs use `network: host` anyway. Untested: dockerd may still fail on cgroup or
overlay setup — try it with a throwaway job before relying on it.

## Invariants (break these and you get double dispatch or leaked runners)

- Job and runner names are `forgejo-runner-<handle>` — the idempotency key.
  `reconcile_orphans` only deletes runners that are `ephemeral`, `offline` **and**
  named `forgejo-runner-*`.
- DinD must stay a native sidecar (`initContainers` + `restartPolicy: Always`),
  or the Job keeps running until `activeDeadlineSeconds` after the runner exits.
- The Job template is inside `autoscaler.sh` (a ConfigMap key). The script hashes
  itself every loop and exits when it changed, so the pod restarts with the new
  version — keep that check.
- One autoscaler (`Recreate`, 1 replica); two would double-dispatch.

## Limits

- Every job starts with a cold DinD (no layer cache between jobs); use
  `cache.external_server` or a shared cache volume if builds get slow.
- Runners are org-level: only repos in the orgs listed in `RUNNERS_API` get CI.
  `MAX_RUNNERS` (2) is shared across them. Each pod's
  runner and DinD containers may each burst to 2 CPU / 3Gi.
- Gitea runners don't carry over; this is Forgejo-only (16+ for user/org runner API).
