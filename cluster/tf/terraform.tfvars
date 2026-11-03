# ==========================================
# Node Configuration
# ==========================================
# disk_size is in GB (number), template_id is the numeric VM ID of your template
proxmox_nodes = {
  # Root disk holds only the OS and container images; volumes live on the data
  # disk (LVM thin pool for OpenEBS, see cluster/ansible/infra/bootstrap/install-openebs-lvm.yml).
  "rke2-node-1" = {
    target_node    = "pve-01"
    storage        = "local-zfs"
    cores          = 8
    memory         = 32768
    disk_size      = 80
    data_disk_size = 250
    template_id    = 1002
    template_node  = "pve-01"
  }
  "rke2-node-2" = {
    target_node    = "pve-02"
    storage        = "local-lvm"
    cores          = 3
    memory         = 8192
    disk_size      = 80
    data_disk_size = 100
    template_id    = 1003
    template_node  = "pve-02"
  }
  "rke2-node-3" = {
    target_node    = "pve-03"
    storage        = "local-lvm"
    cores          = 8
    memory         = 24576
    disk_size      = 80
    data_disk_size = 150
    template_id    = 1004
    template_node  = "pve-03"
  }
}
