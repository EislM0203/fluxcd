# Credential / shared variable names intentionally match lighthouse/tf so the
# existing SOPS .env (TF_VAR_*) satisfies this module without new secrets.

variable "hetzner_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_token" {
  description = "Cloudflare API token with Zone:DNS:Edit permission"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_domain" {
  description = "Root domain of the Cloudflare zone (e.g. traunseenet.com)"
  type        = string
}

variable "edge_server_name" {
  description = "Name for the Hetzner server"
  type        = string
  default     = "edge"
}

variable "edge_server_type" {
  description = "Hetzner server type — cx22 is cheapest Intel, check hetzner.com/cloud for current pricing"
  type        = string
  default     = "cx23"
}

variable "edge_location" {
  description = "Hetzner datacenter location (nbg1, fsn1, hel1)"
  type        = string
  default     = "nbg1"
}

# edge_* names on purpose: lighthouse already uploads ~/.ssh/hetzner.pub to the same
# Hetzner project (duplicate keys are rejected), and the shared TF_VAR_ssh_* names in
# .env collide between modules.
variable "edge_ssh_public_key_path" {
  description = "Path to the SSH public key uploaded to Hetzner and authorized for the edge user"
  type        = string
  default     = "~/.ssh/edge.pub"
}

variable "edge_ssh_username" {
  description = "Non-root user created on the VPS (and on the home VM, see edge/tf/home)"
  type        = string
  default     = "markuseisl"
}

variable "edge_wg_vps_private_key" {
  description = "WireGuard private key of the VPS wg0 interface (TF_VAR_edge_wg_vps_private_key from SOPS .env)"
  type        = string
  sensitive   = true
}

variable "edge_wg_home_public_key" {
  description = "WireGuard public key of the home VM wg-outer interface (non-secret; same as wg_home_outer_public_key in edge/ansible/group_vars/all.yml)"
  type        = string
}

variable "public_hostnames" {
  description = "Names (relative to cloudflare_zone_domain) that get an unproxied A record to the VPS. Temporary until external-dns takes over."
  type        = list(string)
  # oauth.cloud hosts the oauth2-proxy callback; it must be public for any SSO-protected app.
  default = ["whoami.cloud", "oauth.cloud"]
}

variable "acme_account_uri" {
  description = "Optional: cert-manager's ACME account URI (kubectl get clusterissuer letsencrypt-prod -o jsonpath='{.status.acme.uri}'). When set, the CAA records also pin accounturi, so only that account can issue for public_hostnames."
  type        = string
  default     = null

  validation {
    condition     = var.acme_account_uri == null || can(regex("^https://[^\\s;\"]+$", var.acme_account_uri))
    error_message = "acme_account_uri must be an https:// URI without whitespace, ';' or quotes."
  }
}
