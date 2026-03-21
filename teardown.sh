#!/bin/bash
set -e

echo "========================================="
echo " DevSecOps Platform - Teardown Script"
echo "========================================="
echo ""
echo "⚠️  WARNING: This will destroy EVERYTHING."
echo "    All AWS resources will be deleted."
echo "    All data will be lost."
echo ""
read -p "Are you sure? Type 'yes' to continue: " confirm

if [ "$confirm" != "yes" ]; then
  echo "❌ Teardown cancelled."
  exit 0
fi

# Step 1 - Connect kubectl
echo ""
echo "🔗 Connecting kubectl to EKS..."
export EKS_CLUSTER=$(cd ~/devsecops-eks-platform/terraform && terraform output -raw eks_cluster_name 2>/dev/null || echo "")

if [ -z "$EKS_CLUSTER" ]; then
  echo "⚠️  Could not get cluster name. Skipping kubectl steps."
else
  aws eks update-kubeconfig --region us-east-1 --name $EKS_CLUSTER 2>/dev/null || true

  # Step 2 - Uninstall Helm releases
  echo ""
  echo "🗑️  Uninstalling Helm releases..."
  helm uninstall prometheus  -n monitoring 2>/dev/null || true
  helm uninstall fluent-bit  -n logging    2>/dev/null || true
  helm uninstall argocd      -n argocd     2>/dev/null || true
  helm uninstall jenkins     -n jenkins    2>/dev/null || true
  helm uninstall sonarqube   -n sonarqube  2>/dev/null || true

  # Step 3 - Delete LoadBalancer services
  echo ""
  echo "🔧 Deleting LoadBalancer services..."
  kubectl delete svc devsecops-app-service  -n devsecops  2>/dev/null || true
  kubectl delete svc prometheus-grafana     -n monitoring 2>/dev/null || true
  kubectl delete svc argocd-server          -n argocd     2>/dev/null || true
  kubectl delete svc jenkins                -n jenkins    2>/dev/null || true
  kubectl delete svc sonarqube-sonarqube    -n sonarqube  2>/dev/null || true

  echo ""
  echo "⏳ Waiting 60 seconds for LoadBalancers to be released..."
  sleep 60
fi

# Step 4 - Force delete ECR repositories
echo ""
echo "🗑️  Deleting ECR repositories..."
aws ecr delete-repository \
  --repository-name devsecops-app \
  --region us-east-1 --force 2>/dev/null || true

aws ecr delete-repository \
  --repository-name devsecops-ai-service \
  --region us-east-1 --force 2>/dev/null || true

# Step 5 - Terraform destroy
echo ""
echo "💣 Destroying all AWS infrastructure..."
cd ~/devsecops-eks-platform/terraform
terraform destroy -auto-approve

echo ""
echo "========================================="
echo " ✅ Teardown Complete!"
echo "========================================="
echo ""
echo " All AWS resources have been destroyed."
echo " Billing has stopped."
echo ""
echo " To rebuild everything run:"
echo " bash setup.sh"
echo "========================================="