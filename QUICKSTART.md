# Quick Start Guide

## Prerequisites

1. **Install required tools**:
   ```bash
   brew install ansible sops age
   ```

2. **Ensure AGE key is present**:
   ```bash
   # Check if AGE key exists
   ls ~/.config/sops/age/keys.txt
   
   # If not present, copy it from your secure storage or generate one:
   # age-keygen -o ~/.config/sops/age/keys.txt
   ```

## Setup Steps

### 1. Install Ansible Collections
```bash
make install-requirements
```

This installs:
- `community.proxmox` - For VM provisioning
- `community.sops` - For automatic secrets decryption

### 2. Configure Credentials

Edit the following files and replace placeholder values:

**`ansible/infra/provisioning/vars.sops.yml`**:
```yaml
proxmox_api_token_id: "YOUR_TOKEN_ID_HERE"           # TODO: Replace
proxmox_api_token_secret: "YOUR_TOKEN_SECRET_HERE"   # TODO: Replace
vm_cloud_init_password: "changeme"                    # TODO: Replace with secure password
```

**`ansible/inventory_proxmox.sops.yml`**:
```yaml
token_id: "YOUR_TOKEN_ID_HERE"        # TODO: Replace
token_secret: "YOUR_TOKEN_SECRET_HERE" # TODO: Replace
```

### 3. Encrypt Sensitive Files

After filling in real values, encrypt the files:

```bash
# Encrypt vars file (only specific fields)
sops --encrypt \
  --age age1q3mu6g0l3kr7spszks69yqrvlxvlgfrqgw9r00qqt8cj9xpjd9mqdkd7um \
  --encrypted-regex '^(proxmox_api_token_id|proxmox_api_token_secret|vm_cloud_init_password)$' \
  --in-place ansible/infra/provisioning/vars.sops.yml

# Encrypt inventory file (only credentials)
sops --encrypt \
  --age age1q3mu6g0l3kr7spszks69yqrvlxvlgfrqgw9r00qqt8cj9xpjd9mqdkd7um \
  --encrypted-regex '^(token_id|token_secret)$' \
  --in-place ansible/inventory_proxmox.sops.yml
```

### 4. Verify Setup

Test that dynamic inventory works:
```bash
make test-inventory
```

## Usage

### Provision VMs
```bash
make provision-vms
```

Creates VMs on Proxmox with:
- Cloud-init configuration
- Static IP addresses
- SSH key authentication
- Automatic tagging for inventory

### Full Bootstrap
```bash
make bootstrap-infra
```

This runs:
1. `provision-vms` - Create VMs
2. `update-packages` - Update OS packages
3. `install-longhorn-dependencies` - Install storage dependencies
4. `install-rke2-server` - Install RKE2 control plane
5. `install-rke2-agent` - Install RKE2 worker nodes
6. `cluster-readiness-check` - Verify cluster is ready

### Or Bootstrap Everything
```bash
./bootstrap.sh
```

Provisions infrastructure and deploys Flux.

## Individual Commands

```bash
make update-packages                  # Update OS packages on all nodes
make install-longhorn-dependencies    # Install Longhorn storage requirements
make install-rke2-server              # Install RKE2 control plane
make install-rke2-agent               # Install RKE2 worker nodes
make cluster-readiness-check          # Verify all nodes are ready
```

## Editing Encrypted Files

To edit encrypted files:
```bash
sops ansible/infra/provisioning/vars.sops.yml
sops ansible/inventory_proxmox.sops.yml
```

SOPS will automatically decrypt, open in editor, and re-encrypt on save.

## Troubleshooting

### VMs not showing in inventory
```bash
# Check if VMs have correct tags in Proxmox UI
# Required tags: 'rke2', 'rke2-server' or 'rke2-agent'

# Test inventory manually
ansible-inventory -i ansible/inventory_proxmox.sops.yml --list
```

### SOPS decryption fails
```bash
# Verify AGE key is present
cat ~/.config/sops/age/keys.txt

# Ensure SOPS can find it
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
```

### SSH connection issues
```bash
# Test SSH to VMs
ssh -i ~/.ssh/cluster-ssh ansible@10.0.0.200

# Verify SSH key exists
ls -la ~/.ssh/cluster-ssh*
```
