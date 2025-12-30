# To deploy | wipes all disk data, on each call

`sudo nix --extra-experimental-features nix-command --extra-experimental-features flakes run github:nix-community/nixos-anywhere -- --flake /home/markuseisl/fluxcd#lighthouse root@168.119.179.111 -i /home/markuseisl/.ssh/id_ed25519` #had to use password based auth since on nix first reboot(into installer) it would no longer work, constantly ask for password

# rebuilds the flake with the new configuration

`nixos-rebuild switch --flake ~/git/kubernetes/fluxcd#lighthouse --target-host lighthouse` #how i updated the config on the remote system nh os switch ~/git/kubernetes/fluxcd -H lighthouse --ask --target-host lighthouse aditional note, on update, seems local ip addres always switches