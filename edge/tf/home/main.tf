# Reads the VPS public IP from edge/tf/infra. Apply edge/tf/infra first.
# Same S3 backend (credentials come from the same AWS_* env vars as the backend).
data "terraform_remote_state" "infra" {
  backend = "s3"

  config = {
    bucket = "homelab-tf-state"
    key    = "edge/infra/terraform.tfstate"

    endpoints = {
      s3 = "http://10.0.0.154:9000"
    }

    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}

locals {
  vps_public_ip = data.terraform_remote_state.infra.outputs.server_ip
  home_vm_addr  = split("/", var.home_vm_ip)[0]
}

# Console-only password (Proxmox noVNC/serial) for break-glass access, e.g. when the
# outer tunnel or SSH config is broken. Once edge-deploy has run it is not usable over
# SSH: Ansible sets PasswordAuthentication/KbdInteractiveAuthentication no in a sshd
# drop-in that sorts before cloud-init's 50-cloud-init.conf (first value wins). Kept
# only in the edge/home tofu state (sensitive attribute; no output exposes it).
resource "random_password" "vm_password" {
  length  = 32
  special = true
}

# edge-home: the trust boundary. Terminates the outer tunnel from the VPS (only
# 9443/tcp + 51821/udp let through) and the inner admin tunnel (wg-inner).
resource "proxmox_virtual_environment_vm" "edge_home" {
  name      = var.edge_home_vm_name
  vm_id     = var.edge_home_vm_id
  node_name = var.proxmox_node
  on_boot   = true
  started   = true

  tags = [var.edge_home_environment, "proxmox", "terraform", "edge"]

  clone {
    vm_id     = var.edge_home_template_id
    node_name = var.edge_home_template_node
    full      = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores   = var.edge_home_cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = var.edge_home_memory
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    interface    = "scsi0"
    datastore_id = var.edge_home_storage
    size         = var.edge_home_disk_size
    discard      = "on"
    iothread     = true
  }

  network_device {
    model  = "virtio"
    bridge = var.edge_home_network_bridge
  }

  initialization {
    datastore_id = var.edge_home_storage

    ip_config {
      ipv4 {
        address = var.home_vm_ip
        gateway = var.edge_home_vm_gateway
      }
    }

    dns {
      domain  = "local"
      servers = var.edge_home_vm_dns_servers
    }

    user_account {
      username = var.edge_ssh_username
      password = random_password.vm_password.result
      keys     = [trimspace(file(var.edge_ssh_public_key_path))]
    }
  }

  lifecycle {
    ignore_changes = [
      network_device,
    ]
  }
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../../ansible/inventory.ini"
  file_permission = "0600"
  content = templatefile("${path.module}/inventory.tpl", {
    home_vm_ip           = local.home_vm_addr
    vps_public_ip        = local.vps_public_ip
    username             = var.edge_ssh_username
    ssh_private_key_path = var.edge_ssh_private_key_path
    known_hosts_path     = abspath("${path.module}/../../ansible/known_hosts")
  })

  depends_on = [proxmox_virtual_environment_vm.edge_home]
}
