INVENTORY = ansible/inventory.ini
MAINTENANCE_DIR = ansible/infra/maintenance
BOOTSTRAP_DIR = ansible/infra/bootstrap
CLUSTER_DIR = ansible/cluster

SECRETS_FILE = secrets.yaml
TFVARS_FILE = tf/terraform.tfvars
SOPS_AGE_KEY_FILE = $(HOME)/.config/sops/age/keys.txt


bootstrap-infra: apply-tf \
	sleep 10 \
	update-packages \
	install-longhorn-dependencies \
	install-rke2-server \
	install-rke2-agent

bootstrap-workloads: \
	cluster-readiness-check \
	install-argocd

plan-tf:
	tofu -chdir="tf" plan

apply-tf:
	tofu -chdir="tf" apply -auto-approve 

destroy-tf:
	tofu -chdir="tf" destroy -auto-approve 

update-packages:
	ansible-playbook -i "${INVENTORY}" "${MAINTENANCE_DIR}/update-packages.yml"

install-longhorn-dependencies:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-longhorn-dependencies.yml"

install-rke2-server:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-rke2-server.yml"

install-rke2-agent:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/install-rke2-agent.yml"

cluster-readiness-check:
	ansible-playbook -i "${INVENTORY}" "${BOOTSTRAP_DIR}/cluster-readiness-check.yml"

install-argocd:
	ansible-playbook -i "${INVENTORY}" "${CLUSTER_DIR}/install-argocd.yml"