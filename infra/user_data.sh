#!/bin/bash
set -euxo pipefail

LOG_FILE="/var/log/devsecops-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[INFO] Updating system..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

echo "[INFO] Installing Docker..."
apt-get install -y docker.io
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu || true  # Don't fail if ubuntu user doesn't exist

echo "[INFO] Installing kind..."
curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x /usr/local/bin/kind

echo "[INFO] Installing kubectl..."
KUBECTL_VERSION="v1.30.0"
curl -Lo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

echo "[INFO] Installing Node.js (optional)..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

echo "[INFO] Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Create kind cluster
echo "[INFO] Creating kind cluster..."
kind create cluster --name=devsecops-demo-cluster

# Install ArgoCD
echo "[INFO] Installing ArgoCD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "[INFO] Waiting for ArgoCD server to be ready..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

# Show ArgoCD password
if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
  echo "✅ ArgoCD admin password:"
  kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode; echo
else
  echo "✅ ArgoCD admin password (legacy):"
  kubectl get secret argocd-secret -n argocd -o jsonpath="{.data.admin\\.password}" | base64 --decode; echo
fi

# Create ArgoCD app manifest
APP_MANIFEST="/tmp/sample-argocd-app.yaml"
cat <<EOM > $APP_MANIFEST
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

echo "[INFO] Deploying sample ArgoCD application..."
kubectl apply -n argocd -f $APP_MANIFEST

# Install Prometheus and Grafana
echo "[INFO] Installing Prometheus & Grafana via Helm..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring || true
helm install kind-prometheus prometheus-community/kube-prometheus-stack --namespace monitoring

echo "[INFO] Waiting for Prometheus operator to be ready..."
kubectl rollout status deployment/kind-prometheus-kube-prometheus-sta-operator -n monitoring --timeout=300s || true

echo "✅ Grafana admin password:"
kubectl get secret --namespace monitoring kind-prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

echo "🎉 Setup complete. Logs saved to $LOG_FILE"
