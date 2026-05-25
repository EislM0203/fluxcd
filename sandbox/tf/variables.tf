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

variable "sandbox_ssh_public_key_path" {
  description = "Path to the public SSH key authorized on the sandbox VM"
  type        = string
}

variable "sandbox_ssh_private_key_path" {
  description = "Path to the private SSH key Ansible uses to reach the sandbox VM"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
  default     = "production"
}

variable "vm_name" {
  description = "VM name / hostname"
  type        = string
  default     = "sandbox"
}

variable "vm_id" {
  description = "Proxmox VM ID"
  type        = number
  default     = 210
}

variable "target_node" {
  description = "Proxmox node to run the VM on"
  type        = string
  default     = "pve-01"
}

variable "storage" {
  description = "Proxmox datastore for the VM disk and cloud-init"
  type        = string
  default     = "local-zfs"
}

variable "template_id" {
  description = "Numeric VM ID of the template to clone"
  type        = number
  default     = 999
}

variable "template_node" {
  description = "Proxmox node holding the template"
  type        = string
  default     = "pve-01"
}

variable "cores" {
  description = "vCPU cores"
  type        = number
  default     = 8
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 16384
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 100
}

variable "vm_ip" {
  description = "Static IPv4 address (without CIDR)"
  type        = string
  default     = "10.0.0.210"
}

variable "vm_cidr_prefix" {
  description = "CIDR prefix length for the VM IP"
  type        = number
  default     = 24
}

variable "vm_gateway" {
  description = "Default gateway for the VM"
  type        = string
  default     = "10.0.0.138"
}

variable "vm_dns_servers" {
  description = "DNS servers for the VM"
  type        = list(string)
  default     = ["10.0.0.99", "8.8.8.8", "1.1.1.1"]
}

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}
