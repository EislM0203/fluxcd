provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure  = var.proxmox_tls_insecure
}

resource "random_password" "vm_password" {
  length  = 32
  special = true
}

resource "proxmox_virtual_environment_vm" "sandbox" {
  name      = var.vm_name
  vm_id     = var.vm_id
  node_name = var.target_node
  on_boot   = true
  started   = true

  tags = [var.environment, "proxmox", "terraform", "openshell"]

  clone {
    vm_id     = var.template_id
    node_name = var.template_node
    full      = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores   = var.cores
    sockets = 1
    type    = "host" # exposes nested virtualization (KVM) for the libkrun vm driver
  }

  memory {
    dedicated = var.memory
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    interface    = "scsi0"
    datastore_id = var.storage
    size         = var.disk_size
    discard      = "on"
    iothread     = true
  }

  network_device {
    model  = "virtio"
    bridge = var.network_bridge
  }

  initialization {
    datastore_id = var.storage

    ip_config {
      ipv4 {
        address = "${var.vm_ip}/${var.vm_cidr_prefix}"
        gateway = var.vm_gateway
      }
    }

    dns {
      domain  = "local"
      servers = var.vm_dns_servers
    }

    user_account {
      username = "ansible"
      password = random_password.vm_password.result
      keys     = [trimspace(file(var.sandbox_ssh_public_key_path))]
    }
  }

  lifecycle {
    ignore_changes = [
      network_device,
    ]
  }
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"
  content = templatefile("${path.module}/inventory.tpl", {
    vm_name              = var.vm_name
    vm_ip                = var.vm_ip
    ssh_private_key_path = var.sandbox_ssh_private_key_path
  })

  depends_on = [proxmox_virtual_environment_vm.sandbox]
}

output "sandbox_ip" {
  value       = var.vm_ip
  description = "Sandbox VM IP address"
}

output "sandbox_ssh_connection" {
  value       = "ssh -i ${var.sandbox_ssh_private_key_path} ansible@${var.vm_ip}"
  description = "SSH connection string for the sandbox VM"
  sensitive   = true
}
