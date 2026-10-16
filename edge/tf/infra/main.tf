data "cloudflare_zones" "main" {
  name = var.cloudflare_zone_domain
}

# Own key + own name (Hetzner rejects duplicate public keys per project).
resource "hcloud_ssh_key" "edge" {
  name       = "edge"
  public_key = trimspace(file(var.edge_ssh_public_key_path))
}

# Inbound allow-list. Everything else (incl. 22/tcp) is dropped by Hetzner before it
# reaches the VPS. cloud-init leaves sshd on its default listen address (binding it to
# 10.99.0.1 before wg0 exists would lock us out at first boot); Ansible then restricts
# it to 10.99.0.1 and orders ssh.service after wg-quick@wg0. Either way SSH is only
# reachable over wg0, via ProxyCommand through the home VM.
resource "hcloud_firewall" "edge" {
  name = "edge-firewall"

  rule {
    description = "HTTP (301 to HTTPS)"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "HTTPS (HAProxy TCP passthrough to home VM)"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Outer WireGuard (home VM -> VPS)"
    direction   = "in"
    protocol    = "udp"
    port        = "51820"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Inner WireGuard relay (DNAT to home VM wg-inner)"
    direction   = "in"
    protocol    = "udp"
    port        = "51821"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "edge" {
  name         = var.edge_server_name
  server_type  = var.edge_server_type
  image        = "debian-13"
  location     = var.edge_location
  ssh_keys     = [hcloud_ssh_key.edge.id]
  firewall_ids = [hcloud_firewall.edge.id]

  # NOTE: contains the VPS WireGuard private key -> stored in Hetzner's server metadata
  # (readable from the VPS at 169.254.169.254; nft limits that to root) and possibly in
  # tofu state (plaintext or hash: check with `tofu state show hcloud_server.edge`).
  # Acceptable because the key only grants the VPS's own tunnel identity. See README
  # "Key rotation": after a rotation this bootstrap copy is stale, not updated.
  user_data = templatefile("${path.module}/cloud-init.yaml.tpl", {
    ssh_public_key          = trimspace(file(var.edge_ssh_public_key_path))
    username                = var.edge_ssh_username
    wg_vps_private_key      = var.edge_wg_vps_private_key
    wg_home_public_key      = var.edge_wg_home_public_key
    wg_vps_address          = "10.99.0.1/24"
    wg_vps_listen_port      = 51820
    wg_home_outer_allowedip = "10.99.0.2/32"
  })

  lifecycle {
    # Key / cloud-init edits must not recreate the server. This freezes every cloud-init
    # value at creation time; Ansible is the source of truth after bootstrap.
    ignore_changes = [user_data]
  }
}

# Public hostname A records are owned by external-dns now
# (kubernetes/apps/networking/external-dns/external-dns-public): every HTTPRoute on
# Gateway traefik-public gets an unproxied A record -> VPS (+ an ownership TXT
# edge-public-a-<host>). The former tofu-managed A records are only FORGOTTEN here,
# not deleted, so there is no DNS gap (and no 30 min negative caching, SOA minimum
# 1800) during the cutover — see edge/README.md "Cutover to external-dns".
removed {
  from = cloudflare_dns_record.public

  lifecycle {
    destroy = false
  }
}

# CAA on the `cloud` label (NOT the apex). A CA checks the CAA of the requested name
# and climbs to its parents, so this one RRset covers every *.cloud name without its
# own CAA (incl. names external-dns creates later, and the *.cloud wildcard — whose CAA
# lookup starts at cloud.traunseenet.com). Only Let's Encrypt, only via DNS-01 (and,
# if acme_account_uri is set, only for that ACME account). The VPS terminates :80/:443
# for these names, so without this a compromised VPS could obtain a certificate via
# HTTP-01 / TLS-ALPN-01. Verified before moving it here: every issuer for *.cloud uses
# DNS-01 (cluster ClusterIssuer letsencrypt-prod: dns01/cloudflare).
locals {
  caa_value = "letsencrypt.org; validationmethods=dns-01${var.acme_account_uri == null ? "" : "; accounturi=${var.acme_account_uri}"}"
}

resource "cloudflare_dns_record" "caa_cloud" {
  for_each = toset(["issue", "issuewild"])

  zone_id = data.cloudflare_zones.main.result[0].id
  name    = "cloud.${var.cloudflare_zone_domain}"
  type    = "CAA"
  ttl     = 300

  data = {
    flags = 0
    tag   = each.value
    value = local.caa_value
  }
}
