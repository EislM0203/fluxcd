variable "hetzner_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "server_name" {
  description = "Name for the Hetzner server"
  type        = string
  default     = "pangolin"
}

variable "server_type" {
  description = "Hetzner server type — cx22 is cheapest Intel, check hetzner.com/cloud for current pricing"
  type        = string
  default     = "cx22"
}

variable "location" {
  description = "Hetzner datacenter location (nbg1, fsn1, hel1)"
  type        = string
  default     = "nbg1"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key to upload and authorize on the server"
  type        = string
  default     = "~/.ssh/hetzner.pub"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key used by Ansible"
  type        = string
  default     = "~/.ssh/hetzner"
}

variable "ssh_username" {
  description = "Non-root user created on the server"
  type        = string
  default     = "markuseisl"
}

variable "pangolin_base_domain" {
  description = "Base domain for Pangolin (e.g. example.com)"
  type        = string
}

variable "cloudflare_zone_domain" {
  description = "Root domain of the Cloudflare zone (e.g. traunseenet.com)"
  type        = string
}

variable "pangolin_admin_email" {
  description = "Email used for Let's Encrypt certificates and initial admin account"
  type        = string
  sensitive   = true
}

variable "cloudflare_token" {
  description = "Cloudflare API token with Zone:DNS:Edit permission"
  type        = string
  sensitive   = true
}

variable "pangolin_admin_password" {
  description = "Initial admin password for the Pangolin dashboard"
  type        = string
  sensitive   = true
}

variable "image_pangolin" {
  description = "Pangolin Docker image tag"
  type        = string
  default     = "1.20.0"
}

variable "pocketid_base_url" {
  description = "PocketID base URL (e.g. https://pocketid.example.com)"
  type        = string
}

variable "pocketid_client_id" {
  description = "PocketID OAuth2 client ID for Pangolin"
  type        = string
}

variable "pocketid_client_secret" {
  description = "PocketID OAuth2 client secret for Pangolin"
  type        = string
  sensitive   = true
}

variable "image_gerbil" {
  description = "Gerbil Docker image tag"
  type        = string
  default     = "1.4.2"
}

variable "image_traefik" {
  description = "Traefik Docker image tag"
  type        = string
  default     = "v3.6.14"
}

variable "image_crowdsec" {
  description = "CrowdSec Docker image tag"
  type        = string
  default     = "v1.7.8"
}

variable "crowdsec_console_enroll_key" {
  description = "Enrollment key from app.crowdsec.net (empty = skip enrollment)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "crowdsec_discord_webhook_url" {
  description = "Discord webhook URL for high-signal CrowdSec alerts (empty = no notifications)"
  type        = string
  default     = ""
  sensitive   = true
}
