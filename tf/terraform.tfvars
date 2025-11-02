# terraform.tfvars
# ==========================================
# General Configuration
# ==========================================
ssh_public_key_path  = "~/.ssh/cluster-ssh.pub"
ssh_private_key_path = "~/.ssh/cluster-ssh"

# Configure each node individually
# You can specify: target_node, storage, cores, memory, disk_size, template
proxmox_nodes = {
  "rke2-node-1" = {
    target_node = "pve-01"
    storage     = "local-zfs"
    cores       = 3
    memory      = 4096
    disk_size   = "50G"
    template    = "ubuntu-2404-template"
  }
  "rke2-node-2" = {
    target_node = "pve-01"
    storage     = "local-zfs"
    cores       = 3
    memory      = 4096
    disk_size   = "50G"
    template    = "ubuntu-2404-template"
  }
  "rke2-node-3" = {
    target_node = "pve-01"
    storage     = "local-zfs"
    cores       = 3
    memory      = 4096
    disk_size   = "50G"
    template    = "ubuntu-2404-template"
  }
}
