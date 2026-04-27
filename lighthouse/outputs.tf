output "server_ip" {
  value       = hcloud_server.pangolin.ipv4_address
  description = "Public IPv4 address of the Pangolin server"
}

output "pangolin_url" {
  value       = "https://${var.pangolin_base_domain}"
  description = "Pangolin dashboard URL"
}

output "ssh_command" {
  value       = "ssh -i ${var.ssh_private_key_path} ${var.ssh_username}@${hcloud_server.pangolin.ipv4_address}"
  description = "SSH command to connect to the server"
}
