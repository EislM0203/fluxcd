INVENTORY = inventory.ini

update-packages:
	ansible-playbook -i "inventories/${INVENTORY}" "infra/maintenance/update-packages.yml"

apply-wireguard:
	ansible-playbook -i "inventories/${INVENTORY}" "wireguard.yml"

apply-vxlan:
	ansible-playbook -i "inventories/${INVENTORY}" "vxlan_systemd.yml"

apply-vxlan-non-static:
	ansible-playbook -i "inventories/${INVENTORY}" "vxlan.yml"

test-wireguard:
	ansible-playbook -i "inventories/${INVENTORY}" "ping.yml"

test-vxlan:
	ansible-playbook -i "inventories/${INVENTORY}" "ping_vxlan.yml"

install-longhorn-dependencies:
	ansible-playbook -i "inventories/${INVENTORY}" "infra/bootstrap/install-longhorn-dependencies.yml"

install-rke2-server:
	ansible-playbook -i "inventories/${INVENTORY}" "infra/bootstrap/install-rke2-server.yml"

install-rke2-agent:
	ansible-playbook -i "inventories/${INVENTORY}" "infra/bootstrap/install-rke2-agent.yml"