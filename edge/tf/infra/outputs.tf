output "server_ip" {
  value       = hcloud_server.edge.ipv4_address
  description = "Public IPv4 address of the edge VPS (read by edge/tf/home via remote state)"
}
