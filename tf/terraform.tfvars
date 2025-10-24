# terraform.tfvars
# ==========================================
# General Configuration
# ==========================================
ssh_public_key_path  = "~/.ssh/cluster-ssh.pub"
ssh_private_key_path = "~/.ssh/cluster-ssh"

# ==========================================
# Proxmox Configuration
# ==========================================
proxmox_token_id          = "root@pam!terraform"      # Fill this with your Proxmox token ID
proxmox_token_secret      = "a84efd3e-dcee-49d5-9839-342bf06a7ddc"  # Fill this with your Proxmox token secret
proxmox_vm_count          = 3                          # Number of VMs to create
proxmox_vm_name_prefix    = "rke2-node"               # VM name prefix (will create rke2-node-1, rke2-node-2, rke2-node-3)
proxmox_template          = "ubuntu-2404-template"     # Template name
proxmox_target_node       = "pve"                     # Proxmox node name
proxmox_vm_cores          = 3                      # CPU cores per VM
proxmox_vm_memory         = 8192                      # Memory in MB per VM
proxmox_vm_disk_size      = "100G"                     # Disk size per VM
proxmox_vm_storage        = "data-02"               # Storage pool
