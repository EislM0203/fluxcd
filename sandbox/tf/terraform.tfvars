# Sandbox / OpenShell vm-driver gateway VM.
# Defaults live in variables.tf; override here if needed.
vm_name       = "sandbox"
vm_id         = 210
vm_ip         = "10.0.0.210"
target_node   = "pve-01"
storage       = "local-zfs"
template_id   = 999
template_node = "pve-01"
cores         = 8
memory        = 16384
disk_size     = 100
