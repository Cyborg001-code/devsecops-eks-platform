🚀 AI-Driven DevSecOps Platform on AWS EKS

⚡ Production-grade DevSecOps platform featuring
🤖 AI-powered log anomaly detection
🔁 Automated CI/CD
📊 Full observability stack
☁️ Deployed on AWS EKS

📑 Table of Contents

🏗️ Architecture Overview

🛠️ Tech Stack

📁 Project Structure

✨ Features

✅ Prerequisites

⚡ Quick Start

🌐 Services

⚙️ CI/CD Pipeline

🤖 AI Anomaly Detection

📊 Monitoring & Observability

🔔 Slack Alerts

💣 Teardown

🏗️ Architecture Overview
🔁 CI/CD + Cloud Architecture
┌─────────────────────────────────────────────────────────┐
│                    GitHub Actions CI/CD                  │
│         Build → Scan (Trivy) → Push ECR → Deploy EKS   │
└─────────────────────┬───────────────────────────────────┘
                       │
┌─────────────────────▼───────────────────────────────────┐
│                    AWS EKS Cluster                       │
│                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │ devsecops-  │  │ ai-service  │  │   fluent-bit    │ │
│  │    app      │  │             │  │   (DaemonSet)   │ │
│  │ (2 replicas)│  │IsolationFrst│  │                 │ │
│  └──────┬──────┘  └──────┬──────┘  └────────┬────────┘ │
│         │                │                   │          │
│  ┌──────▼──────┐  ┌──────▼──────┐           │          │
│  │ Prometheus  │  │   Grafana   │           │          │
│  │             │  │  Dashboard  │           │          │
│  └─────────────┘  └─────────────┘           │          │
└─────────────────────────────────────────────┼──────────┘
                                              │
┌─────────────────────────────────────────────▼──────────┐
│                        AWS S3                           │
│          Logs Bucket          Models Bucket             │
└─────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────▼──────────────────────────┐
│                      Slack Alerts                       │
│   Anomaly | High Error Rate | High Latency | Training   │
└─────────────────────────────────────────────────────────┘
🛠️ Tech Stack
Category	Technology
☁️ Cloud	AWS (EKS, ECR, S3, VPC, IAM)
🧱 Infrastructure as Code	Terraform
☸️ Container Orchestration	Kubernetes (EKS v1.31)
📦 Package Manager	Helm
⚡ App Framework	Python FastAPI
🐳 Containerization	Docker
🔁 CI/CD	GitHub Actions
🔐 Security Scanning	Trivy
📜 Log Aggregation	Fluent Bit
📊 Metrics	Prometheus
📈 Dashboards	Grafana
🤖 ML Model	Scikit-learn IsolationForest
🔔 Alerting	Slack API
📁 Project Structure
devsecops-eks-platform/
├── app/                        # FastAPI microservice
│   ├── main.py                 # App with structured JSON logging
│   ├── requirements.txt
│   └── Dockerfile
├── ai-service/                 # AI anomaly detection service
│   ├── main.py                 # FastAPI with Slack alerts
│   ├── feature_engineering.py  # S3 log fetcher + feature extractor
│   ├── model.py                # IsolationForest train/predict
│   ├── requirements.txt
│   └── Dockerfile
├── terraform/                  # Infrastructure as Code
│   ├── vpc.tf                  # VPC, subnets, IGW, NAT
│   ├── eks.tf                  # EKS cluster + node group
│   ├── ecr.tf                  # ECR repositories
│   ├── s3.tf                   # S3 buckets (logs + models)
│   ├── iam.tf                  # IAM roles and policies
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── k8s/                        # Kubernetes manifests
│   ├── app-deployment.yaml
│   ├── app-service.yaml
│   ├── ai-service-deployment.yaml
│   ├── ai-service-service.yaml
│   ├── fluent-bit-values.yaml
│   └── grafana-dashboards.yaml
├── .github/workflows/
│   └── ci-cd.yaml              # GitHub Actions pipeline
├── setup.sh                    # One-command setup script
└── README.md
✨ Features
🏗️ Infrastructure

✔ VPC with public and private subnets across 2 availability zones
✔ EKS cluster (v1.31) with auto-scaling node group (t3.small)
✔ ECR repositories with image scanning and lifecycle policies
✔ S3 buckets with encryption, versioning, and public access blocking
✔ IAM roles with least-privilege policies

⚡ Application

✔ FastAPI microservice with structured JSON logging
✔ Middleware capturing:

HTTP method

request path

status code

latency

client IP

✔ Health check endpoint for Kubernetes probes
✔ Error simulation endpoint for anomaly testing

🤖 AI Anomaly Detection

✔ IsolationForest ML model trained on real S3 logs
✔ Feature extraction includes:

error rate

latency

request count

unique IPs

✔ Automatic Slack alerts when anomaly detected
✔ Model stored in S3 for cross-pod availability

⚙️ CI/CD Pipeline

Runs automatically on every push to main branch

✔ Parallel build pipelines
✔ Trivy container security scanning
✔ Automatic deployment to EKS
✔ Rolling updates with verification

📊 Observability

✔ Fluent Bit → ships logs from pods to S3
✔ Prometheus → collects cluster metrics
✔ Grafana dashboards visualize:

Pod CPU usage

Pod memory usage

Restart counts

Node resource utilization

🔔 Slack Alerts

The system sends alerts for:

🚨 Anomaly detected on EKS
⚠️ High error rate (>20%)
🕐 High latency (>500ms)
🧠 Model training complete
❌ No logs found in S3

✅ Prerequisites
Tool	Version
AWS CLI	v2+
Terraform	v1.0+
kubectl	v1.31+
Helm	v3.0+
Docker	v20+
eksctl	v0.100+
⚡ Quick Start
1️⃣ Clone the repository
git clone https://github.com/Cyborg001-code/devsecops-eks-platform.git
cd devsecops-eks-platform
2️⃣ Configure AWS credentials
aws configure

Enter:

Access Key
Secret Key
Region: us-east-1
Output: json
3️⃣ Provision infrastructure
cd terraform
terraform init
terraform apply
4️⃣ Run setup script
cd ..
chmod +x setup.sh
bash setup.sh
This script automatically:

✔ Reads Terraform outputs
✔ Connects kubectl to EKS
✔ Creates namespaces, secrets, ConfigMaps
✔ Builds & pushes Docker images to ECR
✔ Deploys services to Kubernetes
✔ Installs Fluent Bit

5️⃣ Add Slack webhook (optional)
kubectl create secret generic slack-secret \
  --from-literal=SLACK_WEBHOOK_URL=YOUR_WEBHOOK_URL \
  -n devsecops
6️⃣ Install monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=devops123

kubectl patch svc prometheus-grafana \
  -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'
🌐 Services

Get service URLs:

kubectl get svc devsecops-app-service -n devsecops
kubectl get svc prometheus-grafana -n monitoring
Endpoint	Description
GET /	App root
GET /health	Health check
GET /api/data	Sample data endpoint
GET /api/error	Error simulation
GET /health (AI)	AI service health
POST /train	Train anomaly model
POST /predict	Run prediction
⚙️ CI/CD Pipeline
GitHub Actions Flow
Push to main
     │
     ├──► Build and Scan App
     │         ├ Docker build
     │         ├ Trivy scan
     │         └ Push to ECR
     │
     ├──► Build and Scan AI Service
     │         ├ Docker build
     │         ├ Trivy scan
     │         └ Push to ECR
     │
     └──► Deploy to EKS
               ├ Update kubeconfig
               ├ Apply manifests
               ├ Rolling update
               └ Verify rollout
🔐 Required GitHub Secrets
Secret	Description
AWS_ACCESS_KEY_ID	AWS access key
AWS_SECRET_ACCESS_KEY	AWS secret key
AWS_ACCOUNT_ID	AWS account ID
AWS_REGION	AWS region
EKS_CLUSTER_NAME	EKS cluster
🤖 AI Anomaly Detection
How it works

1️⃣ Fluent Bit sends logs → S3
2️⃣ POST /train

Fetch last 20 logs

Extract features

Train IsolationForest

3️⃣ POST /predict

Load model

Score latest logs

Detect anomalies

Features extracted
Feature	Description
requests_per_window	Total requests
error_rate	5xx ratio
count_4xx	Number of 4xx
count_5xx	Number of 5xx
avg_latency_ms	Avg latency
std_latency_ms	Latency variance
unique_ips	Unique clients
🚨 Anomaly Threshold
Score < -0.1 → Anomaly detected
📊 Monitoring & Observability
Access Grafana
kubectl get svc prometheus-grafana -n monitoring

Open EXTERNAL-IP in browser

Login:

Username: admin
Password: devops123
Import dashboards

Recommended dashboards:

15760 → Kubernetes Cluster Overview

Also includes:

DevSecOps Platform Dashboard

(auto-loaded via ConfigMap)

🔔 Slack Alerts
Setup

1️⃣ Go to

https://api.slack.com/apps

2️⃣ Create App
3️⃣ Enable Incoming Webhooks
4️⃣ Add webhook to workspace

Then run:

kubectl create secret generic slack-secret \
  --from-literal=SLACK_WEBHOOK_URL=https://hooks.slack.com/services/XXX/XXX/XXX \
  -n devsecops
💣 Teardown

To avoid AWS charges, destroy resources in this order.

1️⃣ Delete LoadBalancer services
kubectl delete svc devsecops-app-service -n devsecops
kubectl delete svc prometheus-grafana -n monitoring
sleep 60
2️⃣ Delete ECR repositories
aws ecr delete-repository --repository-name devsecops-app --region us-east-1 --force
aws ecr delete-repository --repository-name devsecops-ai-service --region us-east-1 --force
3️⃣ Destroy infrastructure
cd terraform
terraform destroy
👤 Author

Ankush

GitHub:
https://github.com/Cyborg001-code

📄 License

MIT License