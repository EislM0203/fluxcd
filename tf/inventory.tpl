[hetzner]
${server.name} ansible_host=${server.ipv4_address} ansible_user=ansible ansible_ssh_private_key_file=${ssh_private_key_path}

[proxmox]
%{ for vm in proxmox_vms ~}
${vm.name} ansible_host=${vm.ip} ansible_user=ansible ansible_ssh_private_key_file=${ssh_private_key_path}
%{ endfor ~}

[all_vms:children]
hetzner
proxmox