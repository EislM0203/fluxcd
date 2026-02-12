terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.95.0"
    }
  }
}

locals {
  network_parts = split(".", split("/", var.vm_network_cidr)[0])
  network_base  = "${local.network_parts[0]}.${local.network_parts[1]}.${local.network_parts[2]}"

  node_names  = sort(keys(var.nodes))
  node_ip_map = { for idx, name in local.node_names : name => idx }
}

resource "random_password" "vm_password" {
  for_each = var.nodes
  length   = 32
  special  = true
}

resource "proxmox_virtual_environment_vm" "vm" {
  for_each = var.nodes

  name      = each.key
  vm_id     = var.start_ip + local.node_ip_map[each.key]
  node_name = each.value.target_node
  on_boot   = var.start_vm_on_boot
  started   = true

  tags = [var.environment, "proxmox", "terraform"]

  clone {
    vm_id = each.value.template_id
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    interface    = "scsi0"
    datastore_id = each.value.storage
    size         = each.value.disk_size
    discard      = "on"
    iothread     = true
  }

  network_device {
    model  = "virtio"
    bridge = var.network_bridge
  }

  initialization {
    datastore_id = each.value.storage

    ip_config {
      ipv4 {
        address = "${local.network_base}.${var.start_ip + local.node_ip_map[each.key]}/24"
        gateway = var.vm_gateway
      }
    }

    dns {
      domain  = "local"
      servers = var.vm_dns_servers
    }

    user_account {
      username = "ansible"
      password = random_password.vm_password[each.key].result
      keys     = [trimspace(file(var.ssh_public_key_path))]
    }
  }

  lifecycle {
    ignore_changes = [
      network_device,
    ]
  }
}
