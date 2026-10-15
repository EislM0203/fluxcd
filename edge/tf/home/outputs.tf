output "home_vm_ip" {
  value       = local.home_vm_addr
  description = "LAN IP of the edge-home VM"
}

output "vps_public_ip" {
  value       = local.vps_public_ip
  description = "Public IP of the edge VPS (from edge/tf/infra state)"
}

output "ssh_command" {
  value       = "ssh -i ${var.edge_ssh_private_key_path} ${var.edge_ssh_username}@${local.home_vm_addr}"
  description = "SSH command for the edge-home VM"
}
