{
  description = "A very basic flake";

  inputs = {                                            
      nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
      nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
      nixpkgs-master.url = "github:nixos/nixpkgs/master";
      nixos-hardware.url = "github:NixOS/nixos-hardware/master";
      home-manager = { url = "github:nix-community/home-manager"; };
      nix-flatpak.url = "github:gmodena/nix-flatpak";
      nur.url = "github:nix-community/NUR";
      disko = {url = "github:nix-community/disko";
              #  inputs.nixpkgs.follows = "nixpkgs-unstable";
               };
      nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    };
    outputs = { self, ... } @ inputs:   # Function telling flake which inputs to use
	let
		vars = {
			user = "nix";
			location = "$HOME/.flake";
			terminal = "alacritty";
			editor = "vim";
      stateVersion = "25.11";
		};
    inherit (self) outputs;
	in {
		nixosConfigurations = (
			import ./nix {
			inherit inputs outputs self vars;   # Inherit inputs
			}
		);
	};
}