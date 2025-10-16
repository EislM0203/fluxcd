# Proxmox Module Variables

variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 1
}

variable "vm_name_prefix" {
  description = "Name prefix for VMs"
  type        = string
  default     = "proxmox-vm"
}

variable "template" {
  description = "Template name to use for VM creation"
  type        = string
  default     = "debian-13-cloudinit"
}

variable "target_node" {
  description = "Proxmox node to deploy VMs on"
  type        = string
  default     = "pve"
}

variable "cores" {
  description = "Number of CPU cores for each VM"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Amount of memory (MB) for each VM"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Disk size for each VM (e.g., '50G')"
  type        = string
  default     = "50G"
}

variable "storage" {
  description = "Storage pool for VM disks"
  type        = string
  default     = "local-lvm"
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
  default     = ["10.0.0.103", "8.8.8.8", "1.1.1.1"]
}

variable "start_vm_on_boot" {
  description = "Whether to start VM on boot"
  type        = bool
  default     = true
}