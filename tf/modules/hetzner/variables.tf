variable "ssh_key_name" {
  description = "Name for the SSH key in Hetzner Cloud"
  type        = string
  default     = "my-ssh-key"
}

variable "ssh_public_key_path" {
  description = "Path to your public SSH key"
  type        = string
}

variable "firewall_name" {
  description = "Name for the firewall"
  type        = string
  default     = "allow-ssh"
}

variable "environment" {
  description = "Environment label (e.g., development, production)"
  type        = string
  default     = "development"
}

variable "vm_name" {
  description = "Base name for VMs"
  type        = string
  default     = "hetzner-vm"
}

variable "location" {
  description = "Hetzner location (e.g., fsn1, nbg1, hel1)"
  type        = string
  default     = "fsn1"
}

variable "server_type" {
  description = "Hetzner server type (e.g., cx11, cx22)"
  type        = string
  default     = "cx22"
}

variable "image" {
  description = "OS image (e.g., debian-13)"
  type        = string
  default     = "debian-13"
}

variable "tailscale_preauth_key" {
  description = "Tailscale preauth key"
  type        = string
  sensitive   = true
}

variable "tailscale_login_server" {
  description = "Tailscale login server URL"
  type        = string
  default     = "https://headscale.lighthouse.traunseenet.com"
}
