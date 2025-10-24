# ==========================================
# Shared Variables
# ==========================================

variable "ssh_public_key_path" {
  description = "Path to your public SSH key"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to your private SSH key"
  type        = string
}

# ==========================================
# Proxmox Variables
# ==========================================

variable "proxmox_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_vm_count" {
  description = "Number of Proxmox VMs to create"
  type        = number
  default     = 1
}

variable "proxmox_vm_name_prefix" {
  description = "Name prefix for Proxmox VMs"
  type        = string
  default     = "rke2-node"
}

variable "proxmox_template" {
  description = "Template name to use for VM creation"
  type        = string
  default     = "debian-13-cloudinit"
}

variable "proxmox_target_node" {
  description = "Proxmox node to deploy VMs on"
  type        = string
  default     = "pve"
}

variable "proxmox_vm_cores" {
  description = "Number of CPU cores for each VM"
  type        = number
  default     = 2
}

variable "proxmox_vm_memory" {
  description = "Amount of memory (MB) for each VM"
  type        = number
  default     = 2048
}

variable "proxmox_vm_disk_size" {
  description = "Disk size for each VM (e.g., '20G')"
  type        = string
  default     = "20G"
}

variable "proxmox_vm_storage" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}
