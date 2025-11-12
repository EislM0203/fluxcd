MAINTENANCE_DIR = ansible/infra/maintenance
BOOTSTRAP_DIR = ansible/infra/bootstrap
PROVISIONING_DIR = ansible/infra/provisioning
CLUSTER_DIR = ansible/cluster

SECRETS_FILE = secrets.yaml
SOPS_AGE_KEY_FILE = $(HOME)/.config/sops/age/keys.txt


bootstrap-infra: provision-vms \
	update-packages \
	install-longhorn-dependencies \
	install-rke2-server \
	install-rke2-agent \
	cluster-readiness-check

bootstrap-workloads: \
	install-argocd

# Ansible and Python Requirements
install-requirements:
	@echo "Installing Ansible collection requirements (including community.sops)..."
	ansible-galaxy collection install -r ansible/requirements.yml

# Proxmox VM Provisioning
provision-vms:
	@echo "Provisioning VMs on Proxmox..."
	ansible-playbook "${PROVISIONING_DIR}/provision-vms.yml"

# Test dynamic inventory
test-inventory:
	@echo "Testing dynamic inventory..."
	ansible-inventory --list -i ansible/inventory_proxmox.yml

# Legacy Terraform targets (deprecated)
plan-tf:
	@echo "Warning: Terraform is deprecated. Use 'make provision-vms' instead."
	@echo "Skipping terraform plan..."

apply-tf:
	@echo "Warning: Terraform is deprecated. Use 'make provision-vms' instead."
	@echo "Skipping terraform apply..."

destroy-tf:
	@echo "Warning: Terraform is deprecated. Use 'make destroy-vms' instead."
	@echo "Skipping terraform destroy..." 

update-packages:
	ansible-playbook "${MAINTENANCE_DIR}/update-packages.yml"

install-longhorn-dependencies:
	ansible-playbook "${BOOTSTRAP_DIR}/install-longhorn-dependencies.yml"

install-rke2-server:
	ansible-playbook "${BOOTSTRAP_DIR}/install-rke2-server.yml"

install-rke2-agent:
	ansible-playbook "${BOOTSTRAP_DIR}/install-rke2-agent.yml"

cluster-readiness-check:
	ansible-playbook "${BOOTSTRAP_DIR}/cluster-readiness-check.yml"

install-argocd:
	ansible-playbook "${CLUSTER_DIR}/install-argocd.yml"