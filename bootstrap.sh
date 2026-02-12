#!/bin/bash
set -euo pipefail

make bootstrap-infra

kubectl apply --server-side --kustomize ./kubernetes/bootstrap/flux
sops --decrypt kubernetes/bootstrap/flux/age-key.sops.yaml | kubectl apply -f -
kubectl apply -f kubernetes/flux/vars/cluster-settings.yaml
kubectl apply --server-side --kustomize ./kubernetes/flux/config
