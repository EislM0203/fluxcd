# Output VM information
output "vm_ssh_connection_strings" {
  description = "SSH connection strings for the VMs"
  value = [
    for i in range(var.vm_count) : 
    "ssh -i ${var.ssh_private_key_path} ansible@${local.network_base}.${local.start_ip + i}"
  ]
}

output "vms" {
  description = "Complete VM information for use in other resources"
  value = [
    for i, vm in proxmox_vm_qemu.vm : {
      name = vm.name
      id   = vm.vmid
      ip   = "${local.network_base}.${local.start_ip + i}"
      ssh_user = "ansible"
      ssh_connection = "ssh -i ${var.ssh_private_key_path} ansible@${local.network_base}.${local.start_ip + i}"
    }
  ]
}
