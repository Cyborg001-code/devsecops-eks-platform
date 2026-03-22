#!/bin/bash
set -e

echo "========================================="
echo " DevSecOps Platform - Auto Setup Script"
echo "========================================="

# Step 1 - Terraform init and apply
echo ""
echo "🏗️  Provisioning AWS Infrastructure..."
cd ~/devsecops-eks-platform/terraform

terraform init

# Check if EKS cluster already exists
CLUSTER_EXISTS=$(aws eks describe-cluster \
  --name devsecops-cluster \
  --region us-east-1 \
  --query 'cluster.status' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$CLUSTER_EXISTS" == "ACTIVE" ]; then
  echo "✅ EKS cluster already exists and is ACTIVE. Skipping terraform apply."
else
  echo "🏗️  Creating infrastructure..."
  terraform apply -auto-approve
  echo "✅ Infrastructure provisioned!"
fi

# Step 2 - Get Terraform outputs
echo ""
echo "📦 Reading Terraform outputs..."

export S3_LOGS_BUCKET=$(terraform output -raw s3_logs_bucket)
export S3_MODELS_BUCKET=$(terraform output -raw s3_models_bucket)
export ECR_APP_URL=$(terraform output -raw ecr_app_repository_url)
export ECR_AI_URL=$(terraform output -raw ecr_ai_service_repository_url)
export EKS_CLUSTER=$(terraform output -raw eks_cluster_name)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "✅ S3 Logs Bucket:   $S3_LOGS_BUCKET"
echo "✅ S3 Models Bucket: $S3_MODELS_BUCKET"
echo "✅ ECR App:          $ECR_APP_URL"
echo "✅ ECR AI Service:   $ECR_AI_URL"
echo "✅ EKS Cluster:      $EKS_CLUSTER"

# Step 3 - Connect kubectl to EKS
echo ""
echo "🔗 Connecting kubectl to EKS..."
aws eks update-kubeconfig --region us-east-1 --name $EKS_CLUSTER

# Step 4 - Create namespaces
echo ""
echo "📁 Creating namespaces..."
kubectl get namespace devsecops  2>/dev/null || kubectl create namespace devsecops
kubectl get namespace logging    2>/dev/null || kubectl create namespace logging
kubectl get namespace monitoring 2>/dev/null || kubectl create namespace monitoring
kubectl get namespace argocd     2>/dev/null || kubectl create namespace argocd
kubectl get namespace jenkins    2>/dev/null || kubectl create namespace jenkins
kubectl get namespace sonarqube  2>/dev/null || kubectl create namespace sonarqube

# Step 5 - Create AWS credentials secrets
echo ""
echo "🔐 Creating AWS credentials secrets..."
kubectl delete secret aws-credentials -n devsecops 2>/dev/null || true
kubectl create secret generic aws-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id) \
  --from-literal=AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key) \
  --from-literal=AWS_DEFAULT_REGION=us-east-1 \
  -n devsecops

kubectl delete secret aws-credentials -n logging 2>/dev/null || true
kubectl create secret generic aws-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id) \
  --from-literal=AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key) \
  --from-literal=AWS_DEFAULT_REGION=us-east-1 \
  -n logging

kubectl delete secret aws-credentials -n jenkins 2>/dev/null || true
kubectl create secret generic aws-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id) \
  --from-literal=AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key) \
  --from-literal=AWS_DEFAULT_REGION=us-east-1 \
  -n jenkins

# Step 6 - Create ConfigMap with dynamic S3 bucket names
echo ""
echo "⚙️  Creating ConfigMap with S3 bucket names..."
kubectl delete configmap devsecops-config -n devsecops 2>/dev/null || true
kubectl create configmap devsecops-config \
  --from-literal=S3_LOGS_BUCKET=$S3_LOGS_BUCKET \
  --from-literal=S3_MODELS_BUCKET=$S3_MODELS_BUCKET \
  -n devsecops

# Step 7 - Create Slack secret
echo ""
echo "🔔 Creating Slack secret..."
kubectl delete secret slack-secret -n devsecops 2>/dev/null || true
kubectl create secret generic slack-secret \
  --from-literal=SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-"YOUR_SLACK_WEBHOOK_URL"} \
  -n devsecops

# Step 8 - Start Docker and authenticate to ECR
echo ""
echo "🚀 Starting Docker..."
sudo service docker start
sleep 5

echo "🔑 Authenticating Docker to ECR..."
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Step 9 - Build and push images to ECR
echo ""
echo "🔨 Building and pushing App image..."
cd ~/devsecops-eks-platform/app
docker build -t $ECR_APP_URL:latest .
docker push $ECR_APP_URL:latest

echo "🔨 Building and pushing AI Service image..."
cd ~/devsecops-eks-platform/ai-service
docker build -t $ECR_AI_URL:latest .
docker push $ECR_AI_URL:latest

# Step 10 - Deploy app and AI service to EKS
echo ""
echo "☸️  Deploying apps to EKS..."
kubectl apply -f ~/devsecops-eks-platform/k8s/app-deployment.yaml
kubectl apply -f ~/devsecops-eks-platform/k8s/app-service.yaml
kubectl apply -f ~/devsecops-eks-platform/k8s/ai-service-deployment.yaml
kubectl apply -f ~/devsecops-eks-platform/k8s/ai-service-service.yaml

# Step 11 - Update Fluent Bit config with correct bucket name
echo ""
echo "📋 Updating Fluent Bit config with bucket name..."
sed -i "s|bucket .*|bucket $S3_LOGS_BUCKET|g" \
  ~/devsecops-eks-platform/k8s/fluent-bit-values.yaml

# Step 12 - Install Fluent Bit
echo ""
echo "📦 Installing Fluent Bit..."
helm repo add fluent https://fluent.github.io/helm-charts 2>/dev/null || true
helm repo update

helm uninstall fluent-bit -n logging 2>/dev/null || true
sleep 5

helm install fluent-bit fluent/fluent-bit \
  --namespace logging \
  --values ~/devsecops-eks-platform/k8s/fluent-bit-values.yaml \
  --set env[0].name=AWS_ACCESS_KEY_ID \
  --set env[0].valueFrom.secretKeyRef.name=aws-credentials \
  --set env[0].valueFrom.secretKeyRef.key=AWS_ACCESS_KEY_ID \
  --set env[1].name=AWS_SECRET_ACCESS_KEY \
  --set env[1].valueFrom.secretKeyRef.name=aws-credentials \
  --set env[1].valueFrom.secretKeyRef.key=AWS_SECRET_ACCESS_KEY \
  --set env[2].name=AWS_DEFAULT_REGION \
  --set env[2].valueFrom.secretKeyRef.name=aws-credentials \
  --set env[2].valueFrom.secretKeyRef.key=AWS_DEFAULT_REGION

# Step 13 - Install ArgoCD
echo ""
echo "🐙 Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

helm uninstall argocd -n argocd 2>/dev/null || true
sleep 5

helm install argocd argo/argo-cd \
  --namespace argocd \
  --values ~/devsecops-eks-platform/argocd/argocd-values.yaml

echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=300s

# Step 14 - Apply ArgoCD Application
echo ""
echo "🔗 Connecting ArgoCD to GitHub repo..."
kubectl apply -f ~/devsecops-eks-platform/argocd/application.yaml

# Step 15 - Install Jenkins
echo ""
echo "🔧 Installing Jenkins..."
helm repo add jenkins https://charts.jenkins.io 2>/dev/null || true
helm repo update

helm uninstall jenkins -n jenkins 2>/dev/null || true
sleep 5

helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --values ~/devsecops-eks-platform/jenkins/jenkins-values.yaml

echo "⏳ Waiting for Jenkins to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=jenkins \
  -n jenkins --timeout=300s

# Step 16 - Install SonarQube
echo ""
echo "📊 Installing SonarQube..."
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube 2>/dev/null || true
helm repo update

helm uninstall sonarqube -n sonarqube 2>/dev/null || true
sleep 5

helm install sonarqube sonarqube/sonarqube \
  --namespace sonarqube \
  --values ~/devsecops-eks-platform/sonarqube/sonarqube-values.yaml

echo "⏳ Waiting for SonarQube to be ready..."
kubectl wait --for=condition=ready pod \
  -l app=sonarqube \
  -n sonarqube --timeout=300s

# Step 17 - Install Prometheus + Grafana
echo ""
echo "📈 Installing Prometheus + Grafana..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

helm uninstall prometheus -n monitoring 2>/dev/null || true
sleep 5

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=devops123 \
  --set grafana.resources.requests.memory=128Mi \
  --set grafana.resources.limits.memory=256Mi \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.limits.memory=512Mi

kubectl patch svc prometheus-grafana \
  -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'

kubectl apply -f ~/devsecops-eks-platform/k8s/grafana-dashboards.yaml

# Step 18 - Show all service URLs and credentials
echo ""
echo "========================================="
echo " ✅ Setup Complete!"
echo "========================================="
echo ""
echo "📊 Pod Status:"
kubectl get pods -n devsecops
kubectl get pods -n jenkins
kubectl get pods -n argocd
kubectl get pods -n sonarqube
kubectl get pods -n monitoring
kubectl get pods -n logging
echo ""
echo "🌐 Service URLs:"
echo ""
echo "--- App ---"
kubectl get svc devsecops-app-service -n devsecops
echo ""
echo "--- Jenkins ---"
kubectl get svc jenkins -n jenkins
echo ""
echo "--- ArgoCD ---"
kubectl get svc argocd-server -n argocd
echo ""
echo "--- SonarQube ---"
kubectl get svc sonarqube-sonarqube -n sonarqube
echo ""
echo "--- Grafana ---"
kubectl get svc prometheus-grafana -n monitoring
echo ""
echo "========================================="
echo " 🔑 Login Credentials"
echo "========================================="
echo " Jenkins:   admin / devops123"
echo " SonarQube: admin / admin"
echo " Grafana:   admin / devops123"
echo ""
echo " ArgoCD password — run this command:"
echo " kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo " S3 Logs Bucket:   $S3_LOGS_BUCKET"
echo " S3 Models Bucket: $S3_MODELS_BUCKET"
echo "========================================="