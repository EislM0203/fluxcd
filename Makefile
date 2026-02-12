INVENTORY = ansible/inventory.ini
MAINTENANCE_DIR = ansible/infra/maintenance
BOOTSTRAP_DIR = ansible/infra/bootstrap
CLUSTER_DIR = ansible/cluster

SECRETS_FILE = secrets.yaml
TFVARS_FILE = tf/terraform.tfvars
SOPS_AGE_KEY_FILE = $(HOME)/.config/sops/age/keys.txt

.PHONY: bootstrap-infra plan-tf apply-tf destroy-tf wait-for-nodes update-packages \
	install-longhorn-dependencies install-tns-csi-dependencies reboot-if-required install-rke2-server install-rke2-agent cluster-readiness-check

bootstrap-infra: apply-tf \
	wait-for-nodes \
	update-packages \
	install-longhorn-dependencies \
	install-tns-csi-dependencies \
	reboot-if-required \
	install-rke2-server \
	install-rke2-agent \
	cluster-readiness-check

init-tf:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="tf" init

plan-tf:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="tf" plan

apply-tf:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="tf" apply -auto-approve

destroy-tf:
	@set -a && eval "$$(sops --decrypt .env)" && set +a && tofu -chdir="tf" destroy -auto-approve

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
