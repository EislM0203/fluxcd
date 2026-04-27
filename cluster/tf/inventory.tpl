[rke2_server]
%{ for idx, vm in proxmox_vms ~}
%{ if idx == 0 ~}
${vm.name} ansible_host=${vm.ip} ansible_ssh_port=22 ansible_user=ansible ansible_ssh_private_key_file=${ssh_private_key_path} pipelining=true
%{ endif ~}
%{ endfor ~}

[rke2_agents]
%{ for idx, vm in proxmox_vms ~}
%{ if idx > 0 ~}
${vm.name} ansible_host=${vm.ip} ansible_ssh_port=22 ansible_user=ansible ansible_ssh_private_key_file=${ssh_private_key_path} pipelining=true
%{ endif ~}
%{ endfor ~}

[proxmox:children]
rke2_server
rke2_agents

[all_vms:children]
proxmox