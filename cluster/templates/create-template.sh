#!/usr/bin/env bash
# Runs ON a Proxmox host: turns the image from build-debian-image.sh into a VM
# template for cluster/tf (template_id / template_node in terraform.tfvars).
# Settings follow the old Ubuntu templates; the serial port carries the boot log,
# since Debian's cloud kernel logs to ttyS0.
#   usage: create-template.sh <vmid> <storage> <image.qcow2>
set -euo pipefail

VMID=$1
STORAGE=$2
IMAGE=$3

if qm status "$VMID" >/dev/null 2>&1; then
  echo "VM $VMID already exists, refusing to touch it" >&2
  exit 1
fi
[ -f "$IMAGE" ] || { echo "no image at $IMAGE" >&2; exit 1; }

qm create "$VMID" --name debian-13-k8s-template --ostype l26 \
  --memory 2048 --cores 2 --cpu x86-64-v2-AES \
  --agent enabled=1 --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr0 --serial0 socket \
  --tags template,debian13
qm set "$VMID" --scsi0 "${STORAGE}:0,import-from=${IMAGE},discard=on,iothread=1,ssd=1"
qm set "$VMID" --ide0 "${STORAGE}:cloudinit" --boot order=scsi0 --ipconfig0 ip=dhcp
qm template "$VMID"
qm config "$VMID"
