#cloud-config

users:
  - name: ${username}
    groups:
      - sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - ${ssh_public_key}

ssh_pwauth: false
disable_root: true

write_files:
  - path: /etc/apt/apt.conf.d/20auto-upgrades
    content: |
      APT::Periodic::Update-Package-Lists "1";
      APT::Periodic::Download-Upgradeable-Packages "1";
      APT::Periodic::AutocleanInterval "7";
      APT::Periodic::Unattended-Upgrade "1";
  - path: /etc/apt/apt.conf.d/52unattended-upgrades-local
    content: |
      Unattended-Upgrade::Origins-Pattern {
        "origin=Debian,codename=$${distro_codename},label=Debian";
        "origin=Debian,codename=$${distro_codename},label=Debian-Security";
        "origin=Debian,codename=$${distro_codename}-security,label=Debian-Security";
      };
      Unattended-Upgrade::Automatic-Reboot "true";
      Unattended-Upgrade::Automatic-Reboot-Time "04:00";
      Unattended-Upgrade::Remove-Unused-Dependencies "true";
      Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
  # Outer tunnel, VPS side. Bootstrapped here so the home VM can reach the VPS (and
  # Ansible can ProxyJump in) without public SSH. Ansible manages it afterwards.
  - path: /etc/wireguard/wg0.conf
    permissions: "0600"
    owner: root:root
    content: |
      [Interface]
      Address = ${wg_vps_address}
      ListenPort = ${wg_vps_listen_port}
      PrivateKey = ${wg_vps_private_key}

      [Peer]
      # home VM (wg-outer). Hygiene only (a compromised VPS can change this); the real
      # controls are edge-home's wg-outer AllowedIPs + nftables.
      PublicKey = ${wg_home_public_key}
      AllowedIPs = ${wg_home_outer_allowedip}

runcmd:
  - apt-get update
  - apt-get install -y unattended-upgrades wireguard-tools
  - systemctl enable --now wg-quick@wg0
  - systemctl enable --now unattended-upgrades.service
  - unattended-upgrade -v
