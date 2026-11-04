#!/bin/bash
set -euo pipefail

make bootstrap-infra
# Flux has to be installed before Pocket ID runs: use the admin client certificate.
export KUBECONFIG="$HOME/.kube/rke2-admin.yaml"

kubectl apply --server-side --kustomize ./kubernetes/bootstrap/flux
sops --decrypt kubernetes/bootstrap/flux/age-key.sops.yaml | kubectl apply -f -
kubectl apply -f kubernetes/flux/vars/cluster-settings.yaml
kubectl apply --server-side --kustomize ./kubernetes/flux/config
