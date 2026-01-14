# Configure Terraform and required providers
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
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

# Proxmox Module
module "proxmox" {
  source = "./modules/proxmox"
  
  nodes                  = var.proxmox_nodes
  ssh_public_key_path    = var.ssh_public_key_path
  ssh_private_key_path   = var.ssh_private_key_path
  environment            = "development"
}

# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  filename = "../ansible/inventory.ini"
  content = templatefile("${path.module}/inventory.tpl", {
    proxmox_vms = module.proxmox.vms
    ssh_private_key_path = var.ssh_private_key_path
  })
  
  depends_on = [module.proxmox]
}

output "proxmox_ssh_connections" {
  value       = module.proxmox.vm_ssh_connection_strings
  description = "SSH connection strings for Proxmox VMs"
}