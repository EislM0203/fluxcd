# Output VM information
output "vm_ssh_connection_strings" {
  description = "SSH connection strings for the VMs"
  value = [
    for name in local.node_names : 
    "ssh -i ${var.ssh_private_key_path} ansible@${local.network_base}.${local.start_ip + local.node_ip_map[name]}"
  ]
}

output "vms" {
  description = "Complete VM information for use in other resources"
  value = [
    for name in local.node_names : {
      name = proxmox_vm_qemu.vm[name].name
      id   = proxmox_vm_qemu.vm[name].vmid
      ip   = "${local.network_base}.${local.start_ip + local.node_ip_map[name]}"
      ssh_user = "ansible"
      ssh_connection = "ssh -i ${var.ssh_private_key_path} ansible@${local.network_base}.${local.start_ip + local.node_ip_map[name]}"
    }
  ]
}
