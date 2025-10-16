output "server_ips" {
  value = {
    "${hcloud_server.vm.name}" = hcloud_server.vm.ipv4_address
  }
  description = "IP address of the server"
}

output "server_id" {
  value = hcloud_server.vm.id
  description = "ID of the server"
}

# Storage Box will be mounted via SMB/CIFS - no volume outputs needed

output "server" {
  value = hcloud_server.vm
  description = "Server object for inventory generation"
}
