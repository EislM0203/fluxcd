{
  config,
  lib,
  host,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    }
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nix-flatpak.nixosModules.nix-flatpak
    inputs.disko.nixosModules.disko
    ./hardware-configuration.nix
    ./disk-config.nix
    #./vxlan.nix
    # ./traefik.nix
    ./haproxy.nix
    ./acme.nix
    ./pocketid.nix
    # ./headscale.nix
    ./netbird.nix
    {_module.args.disks = ["/dev/sda"];}
  ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = ["rbd" "br_netfilter"];
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.loader = {
    timeout = 1;
    grub.enable = true;
    grub.efiSupport = true;
    grub.efiInstallAsRemovable = true;
  };
  networking.hostName = host.hostName; # Define your hostname.
  programs.nh.enable = true;
  services = {
    openssh = {
      # SSH
      enable = true;
      allowSFTP = true; # SFTP
      extraConfig = ''
        HostKeyAlgorithms +ssh-rsa
      '';
      #settings.PasswordAuthentication = true;
      settings.KbdInteractiveAuthentication = true;
      settings.PermitRootLogin = "yes";
    };
    xserver = {
      xkb.layout = "de";
      xkb.variant = "";
    };
  };
  users.users.root.openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK5R7S6F31wngthy1NMzA+msZpTt5jYeC4h8mER/HF0W"];
  #users.users.root.initialPassword = "nixos";
  users.users.${host.vars.user} = {
    isNormalUser = true;
    #initialPassword = "nixos";
    description = "${host.vars.user}";
    extraGroups = ["networkmanager" "wheel" "docker"];
    # packages = with pkgs; [];
    openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK5R7S6F31wngthy1NMzA+msZpTt5jYeC4h8mER/HF0W"];
  };
  time.timeZone = "Europe/Vienna";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "de_AT.UTF-8";
      LC_IDENTIFICATION = "de_AT.UTF-8";
      LC_MEASUREMENT = "de_AT.UTF-8";
      LC_MONETARY = "de_AT.UTF-8";
      LC_NAME = "de_AT.UTF-8";
      LC_NUMERIC = "de_AT.UTF-8";
      LC_PAPER = "de_AT.UTF-8";
      LC_TELEPHONE = "de_AT.UTF-8";
      LC_TIME = "de_AT.UTF-8";
    };
  };
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    jq
    gparted
    pciutils # lspci
    zip
    p7zip
    unzip
    unrar
    gnutar
    ser2net
    par2cmdline
    rsync
    vim
    nfs-utils
    wireguard-tools
    python3
    cilium-cli
    cni-plugins
    cifs-utils
    git
    kubectl
    vim
    nano
    inetutils
    nettools
    util-linux
    restic
  ];
  system.stateVersion = "${host.vars.stateVersion}";
  nix = {
    settings.auto-optimise-store = true;
    gc = {
      # Garbage Collection
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    package = pkgs.nixVersions.stable;
    extraOptions = "experimental-features = nix-command flakes";
    settings.max-jobs = 4;
  };
  networking.useDHCP = lib.mkForce false; # forcing dissable cus of systemd network
  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "enp1s0";
    networkConfig = {
      # start a DHCP Client for IPv4 Addressing/Routing
      DHCP = "ipv4";
      # accept Router Advertisements for Stateless IPv6 Autoconfiguraton (SLAAC)
      IPv6AcceptRA = true;
    };
    # make routing on this interface a dependency for network-online.target
    linkConfig.RequiredForOnline = "routable";
  };


  networking.firewall = {
    enable = true;
    allowedTCPPorts = [22 80 443 3000 6443 8080 9345 10022];
    allowedUDPPortRanges = [
      {
        from = 1000;
        # to = 6550;
        to = 51900;
      }
    ];
  };
}