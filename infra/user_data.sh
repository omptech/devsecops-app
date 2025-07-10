#!/bin/bash
set -euxo pipefail

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# Install Docker
apt-get install -y docker.io
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Install kind
curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x /usr/local/bin/kind

# Install kubectl
KUBECTL_VERSION="v1.30.0"
curl -Lo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

# Install Node.js (optional, if you need it)
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Write a sample ArgoCD Application manifest
tmp_app_manifest="/tmp/sample-argocd-app.yaml"
cat <<EOM > $tmp_app_manifest
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/omptech/devsecops-app.git'
    targetRevision: HEAD
    path: kubernetes
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOM

# Switch to ubuntu user for kind and kubectl (if running as root)
sudo -i -u ubuntu bash << EOF
set -euxo pipefail

# Create kind cluster
kind create cluster --name=devsecops-demo-cluster

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD server to be ready
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

# Print ArgoCD admin password
if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
  echo "ArgoCD admin password:"
  kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode; echo
else
  echo "ArgoCD admin password (legacy):"
  kubectl get secret argocd-secret -n argocd -o jsonpath="{.data.admin\\.password}" | base64 --decode; echo
fi

# Apply the sample ArgoCD Application manifest
echo "Applying sample ArgoCD Application..."
kubectl apply -n argocd -f $tmp_app_manifest

# Add Prometheus community Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus and Grafana
helm install kind-prometheus prometheus-community/kube-prometheus-stack --namespace monitoring

# Wait for Prometheus operator to be ready
kubectl rollout status deployment/kind-prometheus-kube-prometheus-sta-operator -n monitoring --timeout=300s || true

# Print Grafana admin password
echo "Grafana admin password:"
kubectl get secret --namespace monitoring kind-prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
EOF

echo "Setup complete." 