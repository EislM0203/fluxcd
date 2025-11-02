# Proxmox Module Variables

variable "nodes" {
  description = "Map of node configurations. Each node can have custom target_node, storage, cores, memory, disk_size, and template."
  type = map(object({
    target_node = string
    storage     = string
    cores       = number
    memory      = number
    disk_size   = string
    template    = string
  }))
}

variable "ssh_public_key_path" {
  description = "Path to your public SSH key"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to your private SSH key"
  type        = string
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

variable "vlan_tag" {
  description = "VLAN tag for the network interface (optional)"
  type        = number
  default     = null
}

variable "vm_network_cidr" {
  description = "Network CIDR for VM IP assignment (e.g., '10.0.1.0/24')"
  type        = string
  default     = "10.0.0.0/24"
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
  description = "Whether to start VM on boot"
  type        = bool
  default     = true
}