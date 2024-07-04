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

# Install clusterawsadm.
# brew install clusterawsadm
wget https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases/download/v2.5.2/clusterawsadm_v2.5.2_linux_amd64
sudo mv clusterawsadm_v2.5.2_linux_amd64 /usr/local/bin/clusterawsadm
sudo chmod +x /usr/local/bin/clusterawsadm

# Create Kubernetes Secret required by the Infrastructure provider.

  export CUSTOMERID=
  export AWS_REGION=
  export AWS_ACCESS_KEY_ID=
  export AWS_SECRET_ACCESS_KEY=

  export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)

  kubectl create namespace capi-cluster-kubeaid-demo

  kubectl create secret generic capi-cluster-token \
    --dry-run=client \
    --namespace capi-cluster-kubeaid-demo \
    --from-literal=AWS_B64ENCODED_CREDENTIALS=${AWS_B64ENCODED_CREDENTIALS} \
    -o yaml \
  > ./management-cluster/capi-cluster-token.secret.yaml

  kubectl apply -f ./management-cluster/capi-cluster-token.secret.yaml

# Installing Cluster API :
#
# (1) Clone your mirrored version of the kubeaid-config repo. Add the values-cluster-api.yaml file in
#     the ./k8s/test.cluster.com/argocd-apps/ directory.
#
# (2) Create the Cluster API ArgoCD app in your management cluster.
kubectl apply -f ./management-cluster/cluster-api.app.yaml
#
# (3) Login to the ArgoCD admin dashboard and sync the Cluster API ArgoCD app.
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Bootstrap the main cluster.
kubectl apply -f ./management-cluster/capi-cluster.app.yaml

# Install clusterctl.
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.7.3/clusterctl-linux-amd64 -o clusterctl
sudo install -o root -g root -m 0755 clusterctl /usr/local/bin/clusterctl

# Get kubeconfig of the provisioned cluster.
clusterctl get kubeconfig test.cluster.com -n capi-cluster-kubeaid-demo > ./main-cluster/kubeconfig.yaml
