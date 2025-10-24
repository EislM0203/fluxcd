#!/bin/bash


make plan-tf

make apply-tf \
	update-packages \
	install-longhorn-dependencies \
	install-rke2-server \
	install-rke2-agent \
	cluster-readiness-check

kubectl apply --server-side --kustomize ./kubernetes/bootstrap/flux
sops --decrypt kubernetes/bootstrap/flux/age-key.sops.yaml | kubectl apply -f -
kubectl apply -f kubernetes/flux/vars/cluster-settings.yaml