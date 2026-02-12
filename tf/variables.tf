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
  sensitive   = true
}

# ==========================================
# Proxmox Variables
# ==========================================

variable "proxmox_api_url" {
  description = "Proxmox API endpoint URL (e.g., https://10.0.0.67:8006/)"
  type        = string
}

variable "proxmox_token_id" {
  description = "Proxmox API token ID (e.g., user@pve!terraform)"
  type        = string
  sensitive   = true
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS certificate verification for Proxmox API"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
  default     = "development"
}

variable "proxmox_nodes" {
  description = "Map of node configurations. Each node defines target_node, storage, cores, memory, disk_size (GB), and template_id (numeric VM ID)."
  type = map(object({
    target_node = string
    storage     = string
    cores       = number
    memory      = number
    disk_size   = number
    template_id = number
  }))
  default = {}

  validation {
    condition     = alltrue([for n in values(var.proxmox_nodes) : n.cores > 0 && n.memory >= 1024])
    error_message = "Each node must have at least 1 core and 1024 MB of memory."
  }

  validation {
    condition     = alltrue([for n in values(var.proxmox_nodes) : n.disk_size > 0])
    error_message = "Each node must have a disk_size greater than 0 (in GB)."
  }
}
