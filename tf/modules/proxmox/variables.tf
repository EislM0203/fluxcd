variable "nodes" {
  description = "Map of node configurations. Each node defines target_node, storage, cores, memory, disk_size (GB), and template_id (numeric VM ID)."
  type = map(object({
    target_node = string
    storage     = string
    cores       = number
    memory      = number
    disk_size   = number
    template_id   = number
    template_node = string
  }))
}

variable "ssh_public_key_path" {
  description = "Path to your public SSH key"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to your private SSH key"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment label (e.g., development, production)"
  type        = string
  default     = "development"
}

variable "network_bridge" {
  description = "Network bridge to connect VMs to"
  type        = string
  default     = "vmbr0"
}

variable "vm_network_cidr" {
  description = "Network CIDR for VM IP assignment (e.g., '10.0.0.0/24')"
  type        = string
  default     = "10.0.0.0/24"

  validation {
    condition     = can(cidrhost(var.vm_network_cidr, 0))
    error_message = "Must be a valid CIDR notation (e.g., 10.0.0.0/24)."
  }
}

variable "vm_gateway" {
  description = "Gateway IP for the VMs"
  type        = string
  default     = "10.0.0.138"
}

variable "vm_dns_servers" {
  description = "List of DNS servers for the VMs"
  type        = list(string)
  default     = ["10.0.0.102", "8.8.8.8", "1.1.1.1"]
}

variable "start_vm_on_boot" {
  description = "Whether to start VM on Proxmox host boot"
  type        = bool
  default     = true
}

variable "start_ip" {
  description = "Starting last octet for VM IP assignment (e.g., 201 means first VM gets .201)"
  type        = number
  default     = 201
}
