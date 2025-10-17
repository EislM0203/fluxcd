INVENTORY = ansible/inventory.ini
MAINTENANCE_DIR = ansible/infra/maintenance
BOOTSTRAP_DIR = ansible/infra/bootstrap
VXLAN_DIR = ansible/infra/vxlan

plan-tf:
	tofu -chdir="tf" plan

apply-tf:
	tofu -chdir="tf" apply -auto-approve

destroy-tf:
	tofu -chdir="tf" destroy -auto-approve

bootstrap-infra:
	tofu -chdir="tf" apply -auto-approve
	ansible-playbook -i "${INVENTORY}" "${MAINTENANCE_DIR}/update-packages.yml"
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-tailscale.yml" -e "tailscale_preauth_key="
	ansible-playbook -i "${INVENTORY}" "${VXLAN_DIR}/wireguard.yml"
	ansible-playbook -i "${INVENTORY}" "${VXLAN_DIR}/vxlan_systemd.yml"
	ansible-playbook -i "${INVENTORY}" "${VXLAN_DIR}/ping.yml"
	ansible-playbook -i "${INVENTORY}" "${VXLAN_DIR}/ping_vxlan.yml"
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-longhorn-dependencies.yml"
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-rke2-server.yml"
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-rke2-agent.yml"
	
update-packages:
	ansible-playbook -i "${INVENTORY}" "${MAINTENANCE_DIR}/update-packages.yml"

install-tailscale:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-tailscale.yml" -e "tailscale_preauth_key="

apply-wireguard:
	ansible-playbook -i "${INVENTORY}" "${VXLAN_DIR}/wireguard.yml"

apply-vxlan:
	ansible-playbook -i "${INVENTORY}" "${VXLAN_DIR}/vxlan_systemd.yml"

apply-vxlan-non-static:
	ansible-playbook -i "${INVENTORY}" "${VXLAN_DIR}/vxlan.yml"

test-wireguard:
	ansible-playbook -i "${INVENTORY}" "${VXLAN_DIR}/ping.yml"

test-vxlan:
	ansible-playbook -i "${INVENTORY}" "${VXLAN_DIR}/ping_vxlan.yml"

install-longhorn-dependencies:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-longhorn-dependencies.yml"

install-rke2-server:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-rke2-server.yml"

install-rke2-agent:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-rke2-agent.yml"