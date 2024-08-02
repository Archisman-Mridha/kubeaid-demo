#!/bin/bash

# Create temporary local K3s management cluster.
k3d cluster create management \
  --servers 1 --agents 2

# Install cert manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml

# Install ArgoCD.
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --set notification.enabled=false --set dex.enabled=false
