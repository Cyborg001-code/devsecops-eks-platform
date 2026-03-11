#!/bin/bash
set -e

echo "========================================="
echo " DevSecOps Platform - Auto Setup Script"
echo "========================================="

# Step 1 - Get Terraform outputs
echo ""
echo "📦 Reading Terraform outputs..."
cd ~/devsecops-eks-platform/terraform

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

# Step 2 - Connect kubectl to EKS
echo ""
echo "🔗 Connecting kubectl to EKS..."
aws eks update-kubeconfig --region us-east-1 --name $EKS_CLUSTER

# Step 3 - Create namespaces
echo ""
echo "📁 Creating namespaces..."
kubectl get namespace devsecops 2>/dev/null || kubectl create namespace devsecops
kubectl get namespace logging 2>/dev/null || kubectl create namespace logging
kubectl get namespace monitoring 2>/dev/null || kubectl create namespace monitoring

# Step 4 - Create AWS credentials secrets
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

# Step 5 - Create ConfigMap with dynamic S3 bucket names
echo ""
echo "⚙️  Creating ConfigMap with S3 bucket names..."
kubectl delete configmap devsecops-config -n devsecops 2>/dev/null || true
kubectl create configmap devsecops-config \
  --from-literal=S3_LOGS_BUCKET=$S3_LOGS_BUCKET \
  --from-literal=S3_MODELS_BUCKET=$S3_MODELS_BUCKET \
  -n devsecops

# Step 6 - Update deployment image URLs
echo ""
echo "🐳 Updating deployment image URLs..."


# Step 7 - Start Docker and push images to ECR
echo ""
echo "🚀 Starting Docker..."
sudo service docker start
sleep 5

echo "🔑 Authenticating Docker to ECR..."
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

echo "🔨 Building and pushing App image..."
cd ~/devsecops-eks-platform/app
docker build -t $ECR_APP_URL:latest .
docker push $ECR_APP_URL:latest

echo "🔨 Building and pushing AI Service image..."
cd ~/devsecops-eks-platform/ai-service
docker build -t $ECR_AI_URL:latest .
docker push $ECR_AI_URL:latest

# Step 8 - Deploy app and AI service to EKS
echo ""
echo "☸️  Deploying apps to EKS..."
kubectl apply -f ~/devsecops-eks-platform/k8s/app-deployment.yaml
kubectl apply -f ~/devsecops-eks-platform/k8s/app-service.yaml
kubectl apply -f ~/devsecops-eks-platform/k8s/ai-service-deployment.yaml
kubectl apply -f ~/devsecops-eks-platform/k8s/ai-service-service.yaml

# Step 9 - Update Fluent Bit values with correct bucket
echo ""
echo "📋 Updating Fluent Bit config with bucket name..."
sed -i "s|bucket .*|bucket $S3_LOGS_BUCKET|g" \
  ~/devsecops-eks-platform/k8s/fluent-bit-values.yaml

# Step 10 - Install Fluent Bit
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

# Step 11 - Show final status
echo ""
echo "========================================="
echo " ✅ Setup Complete!"
echo "========================================="
echo ""
echo "📊 Checking pod status..."
kubectl get pods -n devsecops
kubectl get pods -n logging
echo ""
echo "🌐 Getting LoadBalancer URL..."
kubectl get service devsecops-app-service -n devsecops
echo ""
echo "S3 Logs Bucket:   $S3_LOGS_BUCKET"
echo "S3 Models Bucket: $S3_MODELS_BUCKET"