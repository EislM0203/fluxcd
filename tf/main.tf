# Configure Terraform and required providers
terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc03"
    }
  }
}

# Hetzner Cloud provider
provider "hcloud" {
  token = var.hcloud_token
}

# Proxmox provider
provider "proxmox" {
  pm_api_url      = "https://10.0.0.67:8006/api2/json"
  pm_api_token_id = var.proxmox_token_id
  pm_api_token_secret = var.proxmox_token_secret
  pm_parallel = 1
  pm_tls_insecure = true
  pm_minimum_permission_check = false
  pm_log_enable = false
  pm_timeout = 600
}

# Hetzner Cloud Module
module "hetzner" {
  source = "./modules/hetzner"
  
  ssh_public_key_path   = var.ssh_public_key_path
  vm_name               = var.hetzner_vm_name
  server_type           = var.server_type
  image                 = var.image
  location              = var.location
  tailscale_preauth_key = var.tailscale_preauth_key
}

# Proxmox Module
module "proxmox" {
  source = "./modules/proxmox"
  
  vm_count               = var.proxmox_vm_count
  vm_name_prefix         = var.proxmox_vm_name_prefix
  template               = var.proxmox_template
  target_node            = var.proxmox_target_node
  cores                  = var.proxmox_vm_cores
  memory                 = var.proxmox_vm_memory
  disk_size              = var.proxmox_vm_disk_size
  storage                = var.proxmox_vm_storage
  ssh_public_key_path    = var.ssh_public_key_path
  ssh_private_key_path   = var.ssh_private_key_path
  environment            = "development"
}

# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  filename = "../ansible/inventory.ini"
  content = templatefile("${path.module}/inventory.tpl", {
    server = module.hetzner.server
    proxmox_vms = module.proxmox.vms
    ssh_private_key_path = var.ssh_private_key_path
  })
  
  depends_on = [module.hetzner, module.proxmox]
}

#Outputs
output "hetzner_server_ips" {
  value       = module.hetzner.server_ips
  description = "IP addresses of Hetzner servers"
}

output "proxmox_vm_ips" {
  value       = module.proxmox.vm_ips
  description = "IP addresses of Proxmox VMs"
}

output "proxmox_vm_names" {
  value       = module.proxmox.vm_names
  description = "Names of Proxmox VMs"
}

output "proxmox_ssh_connections" {
  value       = module.proxmox.vm_ssh_connection_strings
  description = "SSH connection strings for Proxmox VMs"
}