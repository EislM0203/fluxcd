{inputs, config, system, host, pkgs, pkgs-stable, pkgs-unstable, pkgs-master, ... }:
let
in
{
  home-manager.users.${host.vars.user} = {       # Home-Manager Settings
    home.stateVersion = "${host.vars.stateVersion}";
    programs.home-manager.enable = true;
    xdg.enable= true;
  };
}