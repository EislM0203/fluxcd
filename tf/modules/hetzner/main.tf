terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

# Define the SSH key to use for the VM
resource "hcloud_ssh_key" "default" {
  name       = var.ssh_key_name
  public_key = file(var.ssh_public_key_path)
}

# Define the firewall
resource "hcloud_firewall" "default" {
  name = var.firewall_name
  
  rule {
    direction = "in"
    port      = "22"
    protocol  = "tcp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  
  labels = {
    environment = var.environment
  }
}

# Define the VM instance
resource "hcloud_server" "vm" {
  name        = var.vm_name
  server_type = var.server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.name]
  firewall_ids = [hcloud_firewall.default.id]

  labels = {
    environment = var.environment
  }

  # Cloud-init user data
  user_data = templatefile("${path.module}/cloud-init.tpl", {
    ssh_public_key = file(var.ssh_public_key_path)
    tailscale_preauth_key = var.tailscale_preauth_key
    tailscale_login_server = var.tailscale_login_server
  })
}