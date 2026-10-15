# Rendered by edge/tf/home — do not edit.
# The VPS has no public SSH: it is reached at its wg0 address (10.99.0.1) through the
# home VM. ProxyCommand (instead of a bare ProxyJump) so the jump hop uses the same
# key without relying on ssh-agent / ~/.ssh/config. Both hops verify host keys strictly
# against edge/ansible/known_hosts (pin them out-of-band first, see edge/README.md).

[edge_home]
${home_vm_ip} ansible_user=${username} ansible_ssh_private_key_file=${ssh_private_key_path} ansible_python_interpreter=/usr/bin/python3

[edge_vps]
10.99.0.1 ansible_user=${username} ansible_ssh_private_key_file=${ssh_private_key_path} ansible_python_interpreter=/usr/bin/python3 ansible_ssh_common_args='-o ProxyCommand="ssh -i ${ssh_private_key_path} -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${known_hosts_path} -o GlobalKnownHostsFile=/dev/null -W %h:%p ${username}@${home_vm_ip}"'

[edge_home:vars]
vps_public_ip=${vps_public_ip}

[edge_vps:vars]
vps_public_ip=${vps_public_ip}
