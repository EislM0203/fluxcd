#!/bin/bash
set -euo pipefail

# Flux has to be installed before Pocket ID runs: install-rke2-server writes the
# admin client certificate for this run only, and it is gone again afterwards
# (break-glass: /etc/rancher/rke2/rke2.yaml on the server).
export RKE2_BOOTSTRAP=1
export KUBECONFIG="$HOME/.kube/rke2-admin.yaml"
trap 'rm -f "$KUBECONFIG"' EXIT

make bootstrap-infra

kubectl apply --server-side --kustomize ./kubernetes/bootstrap/flux
sops --decrypt kubernetes/bootstrap/flux/age-key.sops.yaml | kubectl apply -f -
kubectl apply -f kubernetes/flux/vars/cluster-settings.yaml
kubectl apply --server-side --kustomize ./kubernetes/flux/config
