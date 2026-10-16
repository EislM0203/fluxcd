INVENTORY = cluster/ansible/inventory.ini
MAINTENANCE_DIR = cluster/ansible/infra/maintenance
BOOTSTRAP_DIR = cluster/ansible/infra/bootstrap
CLUSTER_DIR = cluster/ansible
EDGE_INFRA_TF_DIR = edge/tf/infra
EDGE_HOME_TF_DIR = edge/tf/home
EDGE_ANSIBLE_DIR = edge/ansible

SECRETS_FILE = secrets.yaml
TFVARS_FILE = cluster/tf/terraform.tfvars

.PHONY: bootstrap-infra plan-tf apply-tf destroy-tf wait-for-nodes configure-hosts-file update-packages configure-sysctl configure-dns \
	install-longhorn-dependencies reboot-if-required install-rke2-server install-rke2-agent cluster-readiness-check \
	edge-infra-init edge-infra-plan edge-infra-apply edge-home-init edge-home-plan edge-home-apply edge-deploy edge-up

bootstrap-infra: apply-tf \
	wait-for-nodes \
	configure-hosts-file \
	update-packages \
	configure-sysctl \
	configure-dns \
	install-longhorn-dependencies \
	reboot-if-required \
	install-rke2-server \
	install-rke2-agent \
	cluster-readiness-check

init-tf:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="cluster/tf" init

plan-tf:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="cluster/tf" plan

apply-tf:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="cluster/tf" apply -auto-approve

destroy-tf:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="cluster/tf" destroy -auto-approve

wait-for-nodes:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/wait-for-nodes.yml"

configure-hosts-file:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/configure-hosts-file.yml"

update-packages:
	ansible-playbook -i "${INVENTORY}" "${MAINTENANCE_DIR}/update-packages.yml"

configure-sysctl:
	ansible-playbook -i "${INVENTORY}" "${MAINTENANCE_DIR}/configure-sysctl.yml"

configure-dns:
	ansible-playbook -i "${INVENTORY}" "${MAINTENANCE_DIR}/configure-dns.yml"

install-longhorn-dependencies:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-longhorn-dependencies.yml"

reboot-if-required:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/reboot-if-required.yml"

install-rke2-server:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-rke2-server.yml"

install-rke2-agent:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-rke2-agent.yml"

cluster-readiness-check:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/cluster-readiness-check.yml"

# ==========================================
# Edge (Hetzner VPS dumb pipe + home VM trust boundary)
# ==========================================

edge-infra-init:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="$(EDGE_INFRA_TF_DIR)" init

edge-infra-plan:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="$(EDGE_INFRA_TF_DIR)" plan

edge-infra-apply:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="$(EDGE_INFRA_TF_DIR)" apply

# Reads server_ip from the edge/infra state and renders edge/ansible/inventory.ini.
edge-home-init:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="$(EDGE_HOME_TF_DIR)" init

edge-home-plan:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="$(EDGE_HOME_TF_DIR)" plan

edge-home-apply:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="$(EDGE_HOME_TF_DIR)" apply

# .env sourced: the playbook reads the WireGuard private keys
# (TF_VAR_edge_wg_vps_private_key, EDGE_WG_HOME_*_PRIVATE_KEY) from the environment.
# Edge's own ansible.cfg: strict host key checking against edge/ansible/known_hosts
# (pinned out-of-band, see edge/README.md); must run from the repo root.
edge-deploy:
	@test -s "$(EDGE_ANSIBLE_DIR)/known_hosts" || { echo "$(EDGE_ANSIBLE_DIR)/known_hosts missing: pin the host keys first (edge/README.md, Host keys)" >&2; exit 1; }
	@set -a && eval "$$(sops --decrypt .env)" && set +a && ANSIBLE_CONFIG="$(EDGE_ANSIBLE_DIR)/ansible.cfg" ansible-playbook -i "$(EDGE_ANSIBLE_DIR)/inventory.ini" "$(EDGE_ANSIBLE_DIR)/site.yml"

edge-up: edge-infra-apply edge-home-apply edge-deploy
