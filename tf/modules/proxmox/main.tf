terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}

# Calculate network base for IP assignment
locals {
  network_parts = split(".", split("/", var.vm_network_cidr)[0])
  network_base  = "${local.network_parts[0]}.${local.network_parts[1]}.${local.network_parts[2]}"
  start_ip      = 201 # Start IPs from .201
  
  # Create ordered list of node names for sequential IP assignment
  node_names = sort(keys(var.nodes))
  node_ip_map = { for idx, name in local.node_names : name => idx }
}

# Create Proxmox VMs
resource "proxmox_vm_qemu" "vm" {
  for_each = var.nodes
  
  vmid        = local.start_ip + local.node_ip_map[each.key]
  name        = each.key
  target_node = each.value.target_node
  clone       = each.value.template
  full_clone  = true
  
  # VM Configuration
  memory      = each.value.memory
  cpu {
    sockets = 1
    cores   = each.value.cores
  }


  
  # Boot settings
  scsihw      = "virtio-scsi-single"
  onboot      = var.start_vm_on_boot
  boot        = "order=ide2;scsi0;net0"
  # VM Options
  agent       = 1
  #os_type     = "cloud-init"
  
  # Disk configuration
  disks {
    scsi {
      scsi0 {
        disk {
          size    = each.value.disk_size
          storage = each.value.storage
          discard    = true    # Enable TRIM/discard
          iothread   = true    # Enable dedicated I/O thread
          #ssd        = true    # Mark as SSD
        }
      }
    }
    ide {
      ide2 {
        cloudinit {
          storage = each.value.storage
        }
      }
    }
  }
  
  # Network configuration
  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
  }
  
  # Cloud-init configuration
  #ipconfig0 = "ip=dhcp"
  # Include DNS servers in ipconfig0 for static IP configuration (required for Ubuntu)
  ipconfig0 = "ip=${local.network_base}.${local.start_ip + local.node_ip_map[each.key]}/24,gw=${var.vm_gateway},dns=${join(" ", var.vm_dns_servers)}"
  
  # Cloud-init settings
  ciuser  = "ansible"
  cipassword = "changeme"
  sshkeys = file(var.ssh_public_key_path)

  
  # Nameserver configuration (also set separately as fallback)
  nameserver = join(" ", var.vm_dns_servers)
  
  # Searchdomain (optional)
  searchdomain = "local"
  
  # Labels for organization
  tags = "${var.environment},proxmox,terraform"
  
  # Lifecycle management
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}