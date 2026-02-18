terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.96.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }

  backend "s3" {
    bucket = "fluxcd-cluster-node-state"
    key    = "fluxcd/terraform.tfstate"

    # MinIO connection - update these values for your environment
    endpoints = {
      s3 = "http://10.0.0.107:9000"
    }

    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure  = var.proxmox_tls_insecure
}

module "proxmox" {
  source = "./modules/proxmox"

  nodes                = var.proxmox_nodes
  ssh_public_key_path  = var.ssh_public_key_path
  ssh_private_key_path = var.ssh_private_key_path
  environment          = var.environment
}

resource "local_file" "ansible_inventory" {
  filename = "../ansible/inventory.ini"
  content = templatefile("${path.module}/inventory.tpl", {
    proxmox_vms          = module.proxmox.vms
    ssh_private_key_path = var.ssh_private_key_path
  })

  depends_on = [module.proxmox]
}

output "proxmox_ssh_connections" {
  value       = module.proxmox.vm_ssh_connection_strings
  description = "SSH connection strings for Proxmox VMs"
  sensitive   = true
}
