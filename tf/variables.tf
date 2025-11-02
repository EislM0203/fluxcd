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

variable "proxmox_nodes" {
  description = "Map of node configurations. Each node can have custom target_node, storage, cores, memory, disk_size, and template."
  type = map(object({
    target_node = string
    storage     = string
    cores       = number
    memory      = number
    disk_size   = string
    template    = string
  }))
  default = {}
}
