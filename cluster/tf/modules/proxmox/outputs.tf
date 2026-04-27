output "vm_ssh_connection_strings" {
  description = "SSH connection strings for the VMs"
  sensitive   = true
  value = [
    for name in local.node_names :
    "ssh -i ${var.ssh_private_key_path} ansible@${local.network_base}.${var.start_ip + local.node_ip_map[name]}"
  ]
}

output "vms" {
  description = "Complete VM information for use in other resources"
  sensitive   = true
  value = [
    for name in local.node_names : {
      name           = proxmox_virtual_environment_vm.vm[name].name
      id             = proxmox_virtual_environment_vm.vm[name].vm_id
      ip             = "${local.network_base}.${var.start_ip + local.node_ip_map[name]}"
      ssh_user       = "ansible"
      ssh_connection = "ssh -i ${var.ssh_private_key_path} ansible@${local.network_base}.${var.start_ip + local.node_ip_map[name]}"
    }
  ]
}
