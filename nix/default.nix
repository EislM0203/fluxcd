{ inputs, vars, ... }:

{
  lighthouse = inputs.nixpkgs-unstable.lib.nixosSystem {
    # system = "x86_64-linux";
    specialArgs = {
      inherit vars inputs;
      host = {
          hostName = "lighthouse-01";
          vars = vars;
          system = "x86_64-linux";
          gpu = "none";
      };
      pkgs-stable   = import inputs.nixpkgs-stable   {system = "x86_64-linux";config.allowUnfree = true;};
      pkgs-unstable = import inputs.nixpkgs-unstable {system = "x86_64-linux";config.allowUnfree = true;};
      pkgs-master   = import inputs.nixpkgs-master   {system = "x86_64-linux";config.allowUnfree = true;};
      system = "x86_64-linux";
    };
    modules = [
        # nur.nixosModules.nur
        ./home-manager.nix
        ./lighthouse
    ];
  };
}