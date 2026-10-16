# Proxmox credential names match cluster/tf so the existing SOPS .env
# (TF_VAR_proxmox_*) satisfies this module without new secrets.

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

# --- required, no defaults (set in terraform.tfvars or TF_VAR_*) ---

variable "home_vm_ip" {
  description = "Static LAN IPv4 of the edge-home VM in CIDR form, e.g. \"10.0.0.x/24\""
  type        = string

  validation {
    condition     = can(cidrhost(var.home_vm_ip, 0)) && length(split("/", var.home_vm_ip)) == 2
    error_message = "home_vm_ip must be in CIDR form, e.g. \"10.0.0.x/24\"."
  }
}

variable "proxmox_node" {
  description = "Proxmox node to run the edge-home VM on"
  type        = string
}

# --- SSH (edge_* names avoid the shared TF_VAR_ssh_* collision between modules) ---

variable "edge_ssh_public_key_path" {
  description = "Path to the SSH public key authorized for the edge user"
  type        = string
  default     = "~/.ssh/edge.pub"
}

variable "edge_ssh_private_key_path" {
  description = "Path to the SSH private key Ansible uses for edge-home and (via ProxyCommand) the VPS"
  type        = string
  default     = "~/.ssh/edge"
}

variable "edge_ssh_username" {
  description = "User created on the home VM (keep equal to edge/tf/infra's edge_ssh_username)"
  type        = string
  default     = "markuseisl"
}

# --- VM shape ---

variable "edge_home_environment" {
  description = "Deployment environment label"
  type        = string
  default     = "production"
}

variable "edge_home_vm_name" {
  description = "VM name / hostname"
  type        = string
  default     = "edge-home"
}

variable "edge_home_vm_id" {
  description = "Proxmox VM ID (null = next free ID)"
  type        = number
  default     = null
}

variable "edge_home_storage" {
  description = "Proxmox datastore for the VM disk and cloud-init (must exist on proxmox_node)"
  type        = string
  default     = "local-zfs"
}

variable "edge_home_template_id" {
  description = "Numeric VM ID of the Debian cloud-init template to clone"
  type        = number
  default     = 999
}

variable "edge_home_template_node" {
  description = "Proxmox node holding the template"
  type        = string
  default     = "pve-01"
}

variable "edge_home_cores" {
  description = "vCPU cores"
  type        = number
  default     = 1
}

variable "edge_home_memory" {
  description = "Memory in MB"
  type        = number
  default     = 1024
}

variable "edge_home_disk_size" {
  description = "Disk size in GB (must be >= the template's disk)"
  type        = number
  default     = 50
}

variable "edge_home_vm_gateway" {
  description = "Default gateway for the VM"
  type        = string
  default     = "10.0.0.138"
}

variable "edge_home_vm_dns_servers" {
  description = "DNS servers for the VM (split-horizon resolver only; public resolvers return the WAN IP)"
  type        = list(string)
  default     = ["10.0.0.99"]
}

variable "edge_home_network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}
