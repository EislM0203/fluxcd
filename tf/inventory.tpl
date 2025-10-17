[hetzner]
${server.name} ansible_host=${server.ipv4_address} ansible_ssh_port=22 ansible_user=ansible ansible_ssh_private_key_file=${ssh_private_key_path} pipelining=true wireguard_ip=10.200.10.1 vxlan_ip=10.200.11.1

[proxmox]
%{ for vm in proxmox_vms ~}
${vm.name} ansible_host=${vm.ip} ansible_ssh_port=22 ansible_user=ansible ansible_ssh_private_key_file=${ssh_private_key_path} pipelining=true wireguard_ip=${vm.wireguard_ip} vxlan_ip=${vm.vxlan_ip}
%{ endfor ~}

[all_vms:children]
hetzner
proxmox

[all:vars]
ufw_enabled=false
ansible_become_method=sudo
wireguard_interface=wg0
wireguard_mask_bits=24
wireguard_port=51872
ansible_ssh_common_args=-o StrictHostKeyChecking=no
vxlan_mask_bits=24
vxlan_interface=vx0