# ==========================================
# General Configuration
# ==========================================
ssh_public_key_path  = "~/.ssh/cluster-ssh.pub"
ssh_private_key_path = "~/.ssh/cluster-ssh"
proxmox_api_url      = "https://10.0.0.67:8006/"
proxmox_tls_insecure = true

# ==========================================
# Node Configuration
# ==========================================
# disk_size is in GB (number), template_id is the numeric VM ID of your template
proxmox_nodes = {
  "rke2-node-1" = {
    target_node = "pve-01"
    storage     = "local-zfs"
    cores       = 4
    memory      = 16384
    disk_size   = 500
    template_id = 999
  }
  "rke2-node-2" = {
    target_node = "pve-02"
    storage     = "local-lvm"
    cores       = 3
    memory      = 8192
    disk_size   = 200
    template_id = 1000
  }
  "rke2-node-3" = {
    target_node = "pve-01"
    storage     = "local-zfs"
    cores       = 4
    memory      = 12288
    disk_size   = 500
    template_id = 999
  }
}
