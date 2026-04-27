terraform {
  required_version = ">= 1.6.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.60"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket = "fluxcd-cluster-node-state"
    key    = "hetzner-pangolin/terraform.tfstate"

    endpoints = {
      s3 = "http://10.0.0.107:9000"
    }

    region                      = "us-east-1"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}

provider "hcloud" {
  token = var.hetzner_token
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}

locals {
  # Derive the DNS record name relative to the Cloudflare zone.
  # e.g. pangolin_base_domain="pg.traunseenet.com", cloudflare_zone_domain="traunseenet.com" → "pg"
  pangolin_dns_name = trimsuffix(var.pangolin_base_domain, ".${var.cloudflare_zone_domain}")
}

data "cloudflare_zones" "main" {
  filter {
    name = var.cloudflare_zone_domain
  }
}

resource "random_password" "pangolin_secret" {
  length           = 48
  special          = true
  override_special = "!@#$%^&*"
}

resource "hcloud_ssh_key" "main" {
  name       = "hetzner-pangolin-key"
  public_key = trimspace(file(var.ssh_public_key_path))
}

resource "hcloud_firewall" "pangolin" {
  name = "pangolin-firewall"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "51820"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "21820"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "pangolin" {
  name         = var.server_name
  server_type  = var.server_type
  image        = "debian-13"
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.main.id]
  firewall_ids = [hcloud_firewall.pangolin.id]

  user_data = templatefile("${path.module}/cloud-init.yaml.tpl", {
    ssh_public_key = trimspace(file(var.ssh_public_key_path))
    username       = var.ssh_username
  })
}

# Dashboard: pg.traunseenet.com
resource "cloudflare_record" "pangolin_dashboard" {
  zone_id = data.cloudflare_zones.main.zones[0].id
  name    = local.pangolin_dns_name
  content = hcloud_server.pangolin.ipv4_address
  type    = "A"
  ttl     = 60
  proxied = false
}

# Tunnel resources: *.pg.traunseenet.com
resource "cloudflare_record" "pangolin_wildcard" {
  count   = var.create_wildcard_dns ? 1 : 0
  zone_id = data.cloudflare_zones.main.zones[0].id
  name    = "*.${local.pangolin_dns_name}"
  content = hcloud_server.pangolin.ipv4_address
  type    = "A"
  ttl     = 60
  proxied = false
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0600"
  content         = templatefile("${path.module}/inventory.tpl", {
    server_ip               = hcloud_server.pangolin.ipv4_address
    username                = var.ssh_username
    ssh_private_key_path    = var.ssh_private_key_path
    pangolin_base_domain    = var.pangolin_base_domain
    pangolin_dashboard_url  = var.pangolin_base_domain
    pangolin_admin_email    = var.pangolin_admin_email
    pangolin_secret         = random_password.pangolin_secret.result
    pangolin_admin_password = var.pangolin_admin_password
    cloudflare_token        = var.cloudflare_token
    image_pangolin          = var.image_pangolin
    image_gerbil            = var.image_gerbil
    image_traefik           = var.image_traefik
    image_crowdsec          = var.image_crowdsec
    image_crowdsec_manager  = var.image_crowdsec_manager
  })

  depends_on = [hcloud_server.pangolin]
}
