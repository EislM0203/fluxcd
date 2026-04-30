INVENTORY = cluster/ansible/inventory.ini
MAINTENANCE_DIR = cluster/ansible/infra/maintenance
BOOTSTRAP_DIR = cluster/ansible/infra/bootstrap
CLUSTER_DIR = cluster/ansible
LIGHTHOUSE_ANSIBLE_DIR = lighthouse/ansible

SECRETS_FILE = secrets.yaml
TFVARS_FILE = cluster/tf/terraform.tfvars
SOPS_AGE_KEY_FILE = $(HOME)/.config/sops/age/keys.txt

.PHONY: bootstrap-infra plan-tf apply-tf destroy-tf wait-for-nodes update-packages \
	install-longhorn-dependencies install-tns-csi-dependencies reboot-if-required install-rke2-server install-rke2-agent cluster-readiness-check \
	install-netbird \
	lighthouse-init lighthouse-plan lighthouse-apply lighthouse-bootstrap lighthouse-setup lighthouse-configure lighthouse-redeploy lighthouse-destroy

bootstrap-infra: apply-tf \
	wait-for-nodes \
	update-packages \
	install-longhorn-dependencies \
	install-tns-csi-dependencies \
	install-netbird \
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

update-packages:
	ansible-playbook -i "${INVENTORY}" "${MAINTENANCE_DIR}/update-packages.yml"

install-longhorn-dependencies:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-longhorn-dependencies.yml"

install-tns-csi-dependencies:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-tns-csi-dependencies.yml"

reboot-if-required:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/reboot-if-required.yml"

install-rke2-server:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-rke2-server.yml"

install-rke2-agent:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-rke2-agent.yml"

cluster-readiness-check:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/cluster-readiness-check.yml"

# ==========================================
# Hetzner Lighthouse
# ==========================================

lighthouse-init:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="lighthouse/tf" init -reconfigure

lighthouse-plan:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="lighthouse/tf" plan

lighthouse-apply:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="lighthouse/tf" apply

lighthouse-bootstrap:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="lighthouse/tf" apply -auto-approve
	ansible-playbook -i "${LIGHTHOUSE_ANSIBLE_DIR}/inventory.ini" "${LIGHTHOUSE_ANSIBLE_DIR}/site.yml"

lighthouse-setup:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && ansible-playbook -i "${LIGHTHOUSE_ANSIBLE_DIR}/inventory.ini" "${LIGHTHOUSE_ANSIBLE_DIR}/setup.yml"

lighthouse-configure:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && ansible-playbook -i "${LIGHTHOUSE_ANSIBLE_DIR}/inventory.ini" "${LIGHTHOUSE_ANSIBLE_DIR}/configure.yml"

lighthouse-destroy:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="lighthouse/tf" destroy -auto-approve
