#!/usr/bin/env bash
# Builds the RKE2 node image from Debian's official cloud image, on the workstation
# (needs guestfs-tools). The cloud image lacks the QEMU guest agent, which OpenTofu
# waits for (agent { enabled = true }), the packages OpenEBS LVM and NFS mounts
# need, procps (sysctl, used by the sysctl playbook) and iptables (as on Ubuntu).
# Output: debian-13-k8s-<date>.qcow2 in the work dir, for create-template.sh.
set -euo pipefail

command -v dhcpcd >/dev/null || { echo "install dhcpcd first (libguestfs appliance networking)" >&2; exit 1; }

WORK_DIR=${1:-./work}
BASE_URL=https://cloud.debian.org/images/cloud/trixie/latest
IMAGE=debian-13-genericcloud-amd64.qcow2
OUT="debian-13-k8s-$(date +%Y%m%d).qcow2"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

curl -fsSLO "$BASE_URL/$IMAGE"
curl -fsSL "$BASE_URL/SHA512SUMS" -o SHA512SUMS
grep " $IMAGE\$" SHA512SUMS | sha512sum -c -

cp "$IMAGE" "$OUT"
# The libguestfs appliance gets its network address via the host's dhcpcd binary;
# without dhcpcd installed on the workstation it has no network and apt fails.
# machine-id and cloud-init state are cleared so every clone gets its own identity
# and runs cloud-init as a first boot.
virt-customize -a "$OUT" \
  --update \
  --install qemu-guest-agent,lvm2,thin-provisioning-tools,nfs-common,procps,iptables \
  --run-command 'systemctl enable qemu-guest-agent' \
  --run-command 'cloud-init clean --logs --seed' \
  --truncate /etc/machine-id

sha256sum "$OUT" | tee "$OUT.sha256"
