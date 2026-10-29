# Proxmox hosts and guests (survey 2026-10-28, read-only)

Rules: the agent has no host access and only guides (`proxmox-safe-ops`). Changes go through OpenTofu or the user's scripts, always agreed with the user first.

## Nodes

Three nodes, Proxmox VE 9.2, no HA.
- node 1: ZFS root pool, hosts most guests.
- node 2: one RKE2 node VM.
- node 3: one RKE2 node VM and one small LXC.

## Guests (by id)

| Id | Kind | Role | Managed by | Backup job |
|---|---|---|---|---|
| 105 | LXC | internal DNS server (every node and client resolves through it), no update script | by hand | yes (stop mode) |
| 103 | LXC | reverse proxy for non-cluster services | `npm.sh` | yes (stop mode) |
| 101 | LXC | WireGuard | `wireguard.sh` | yes |
| 114 | LXC | oCIS | `ocis.sh` | yes |
| 151 | VM, stopped | Docker host | `docker.sh` | yes |
| 211 | VM, stopped | Hermes agent | by hand | local only |
| 104 | LXC | Ollama | by hand | none |
| 102 | LXC | Stirling PDF (node 3) | `stirling.sh` | none |
| 899 | VM | Proxmox Backup Server, datastore on the NAS | by hand | none: special rules in `proxmox-snapshot-backup` |
| 106 | VM | home edge VM | `edge/tf/home` | none (rebuildable from OpenTofu and Ansible) |
| 201 to 203 | VM | RKE2 nodes, one per node | `cluster/tf` | none by design, data backed up in the cluster |
| 230 | VM | podman host, DHCP | by hand | none |
| 250 | VM | unused TrueNAS VM | by hand | none |
| 100 | VM | firewall | out of scope | out of scope |
| 998 to 1001 | templates | VM templates for OpenTofu | | |

Update scripts are in the user's `proxmox-update-scripts` repo (`ct/<name>.sh`).

## Backup jobs

- 01:00 to the backup server on the NAS, mode stop, keep all.
- 02:00 to local storage, mode stop, same guests plus 211.
- Mode stop takes DNS and the reverse proxy down twice a night; snapshot mode would avoid that (open decision of the user).

## Storage outside the cluster

A TrueNAS SCALE NAS holds the backup server datastore and an S3 service (RustFS) used for the OpenTofu state, VolSync and CNPG backups.

## Boot order gotchas

- DNS (105) has no startup order set; clients that boot first fail to resolve.
- The unused TrueNAS VM has startup order 2 with a 120 s delay.
- The RKE2 VMs carry the tag "development" although they run the production cluster.
