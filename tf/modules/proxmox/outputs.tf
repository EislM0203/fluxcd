# Output VM information
output "vm_names" {
  description = "Names of the created VMs"
  value       = proxmox_vm_qemu.vm[*].name
}

output "vm_ids" {
  description = "VM IDs in Proxmox"
  value       = proxmox_vm_qemu.vm[*].vmid
}

output "vm_ips" {
  description = "IP addresses of the VMs"
  value = [
    for i in range(var.vm_count) : 
    "${local.network_base}.${local.start_ip + i}"
  ]
}

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
      wireguard_ip   = "10.200.10.${i + 2}"   # example
      vxlan_ip       = "10.200.11.${i + 2}"   # example
      ssh_user = "ansible"
      ssh_connection = "ssh -i ${var.ssh_private_key_path} ansible@${local.network_base}.${local.start_ip + i}"
    }
  ]
}
