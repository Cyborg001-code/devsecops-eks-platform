# 🚀 AI-Driven DevSecOps Platform on AWS EKS

A production-grade DevSecOps platform featuring AI-powered log anomaly detection, automated CI/CD pipeline with security scanning, and a full observability stack — all deployed on AWS EKS.

---

## 🏗️ Architecture

![Architecture](https://raw.githubusercontent.com/Cyborg001-code/devsecops-eks-platform/main/docs/images/Architecture.png)

---

## 📸 Screenshots

### ⚙️ CI/CD Pipeline — GitHub Actions
![CI/CD Pipeline](https://raw.githubusercontent.com/Cyborg001-code/devsecops-eks-platform/main/docs/images/CI-CD%20Pipeline.JPG)

### 📊 Grafana Dashboard — Live Kubernetes Metrics
![Grafana Dashboard](https://raw.githubusercontent.com/Cyborg001-code/devsecops-eks-platform/main/docs/images/Grafana%20Dashboard.JPG)

### 🔔 Slack Alerts — AI Anomaly Detection
![Slack Alerts](https://raw.githubusercontent.com/Cyborg001-code/devsecops-eks-platform/main/docs/images/Slack%20alert.JPG)

---

## 📋 Table of Contents

- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Services](#services)
- [CI/CD Pipeline](#cicd-pipeline)
- [AI Anomaly Detection](#ai-anomaly-detection)
- [Monitoring and Observability](#monitoring-and-observability)
- [Slack Alerts](#slack-alerts)
- [Teardown](#teardown)

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|-----------|
| Cloud | AWS (EKS, ECR, S3, VPC, IAM) |
| Infrastructure as Code | Terraform |
| Container Orchestration | Kubernetes (EKS v1.31) |
| Package Manager | Helm |
| App Framework | Python FastAPI |
| Containerization | Docker |
| CI/CD | GitHub Actions |
| Security Scanning | Trivy |
| Log Aggregation | Fluent Bit |
| Metrics | Prometheus |
| Dashboards | Grafana |
| ML Model | Scikit-learn IsolationForest |
| Alerting | Slack API |

---

## 📁 Project Structure

```
devsecops-eks-platform/
├── app/                          # FastAPI microservice
│   ├── main.py                   # App with structured JSON logging
│   ├── requirements.txt
│   └── Dockerfile
├── ai-service/                   # AI anomaly detection service
│   ├── main.py                   # FastAPI with Slack alerts
│   ├── feature_engineering.py    # S3 log fetcher + feature extractor
│   ├── model.py                  # IsolationForest train/predict
│   ├── requirements.txt
│   └── Dockerfile
├── terraform/                    # Infrastructure as Code
│   ├── vpc.tf                    # VPC, subnets, IGW, NAT
│   ├── eks.tf                    # EKS cluster + node group
│   ├── ecr.tf                    # ECR repositories
│   ├── s3.tf                     # S3 buckets (logs + models)
│   ├── iam.tf                    # IAM roles and policies
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── k8s/                          # Kubernetes manifests
│   ├── app-deployment.yaml
│   ├── app-service.yaml
│   ├── ai-service-deployment.yaml
│   ├── ai-service-service.yaml
│   ├── fluent-bit-values.yaml
│   └── grafana-dashboards.yaml
├── .github/workflows/
│   └── ci-cd.yaml                # GitHub Actions pipeline
├── docs/images/                  # Project screenshots
├── setup.sh                      # One-command setup script
└── README.md
```

---

## ✨ Features

### 🏗️ Infrastructure
- **VPC** with public and private subnets across 2 availability zones
- **EKS cluster** (v1.31) with auto-scaling node group (t3.small)
- **ECR** repositories with image scanning and lifecycle policies
- **S3** buckets with AES256 encryption, versioning, and public access blocking
- **IAM** roles with least-privilege policies
- Entire infrastructure recreatable with single `terraform apply`

### 🐳 Application
- FastAPI microservice with structured JSON logging
- Middleware capturing method, path, status code, latency, client IP
- Health check endpoint for Kubernetes liveness and readiness probes
- Error simulation endpoint for anomaly testing
- 2 replicas with rolling deployment strategy

### 🤖 AI Anomaly Detection
- IsolationForest ML model trained on real application logs from S3
- 7 features extracted per log window: error rate, latency, request count, unique IPs
- Automatic Slack alerts when anomaly score drops below threshold (-0.1)
- Model persisted to S3 — survives pod restarts and redeployments

### 🔒 CI/CD + Security
- GitHub Actions pipeline triggers on every push to `main`
- Parallel build jobs for App and AI Service
- Trivy container security scanning for HIGH and CRITICAL vulnerabilities
- Automatic rolling deployment to EKS
- Deployment health verified with rollout status check
- Full pipeline completes in under 3 minutes

### 📊 Observability
- **Fluent Bit** DaemonSet collecting structured logs from all app pods → S3
- **Prometheus** scraping metrics from entire EKS cluster
- **Custom Grafana dashboard** showing:
  - Pod CPU usage (per pod, time series)
  - Pod memory usage (per pod, time series)
  - Pod restart count
  - Running pod count
  - Node CPU usage gauge
  - Node memory usage gauge

### 🔔 Slack Alerts
- 🚨 Anomaly detected on EKS (with full feature breakdown)
- ⚠️ High error rate alert (>20% threshold)
- 🕐 High latency alert (>500ms threshold)
- 🧠 AI model training complete notification
- ❌ No logs found in S3 (Fluent Bit health check)

---

## ✅ Prerequisites

| Tool | Version |
|------|---------|
| AWS CLI | v2+ |
| Terraform | v1.0+ |
| kubectl | v1.31+ |
| Helm | v3.0+ |
| Docker | v20+ |
| eksctl | v0.100+ |

---

## ⚡ Quick Start

### 1. Clone the repository
```bash
git clone https://github.com/Cyborg001-code/devsecops-eks-platform.git
cd devsecops-eks-platform
```

### 2. Configure AWS credentials
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output (json)
```

### 3. Provision infrastructure
```bash
cd terraform
terraform init
terraform apply
```
> ⏱️ Takes approximately 25-30 minutes for EKS cluster to be ready.

### 4. Run the setup script
```bash
cd ..
chmod +x setup.sh
bash setup.sh
```

This single script automatically handles everything:
- Reads Terraform outputs (dynamic S3 bucket names, ECR URLs)
- Connects kubectl to EKS cluster
- Creates namespaces: `devsecops`, `logging`, `monitoring`
- Creates AWS credentials secrets
- Creates ConfigMap with S3 bucket names
- Builds and pushes Docker images to ECR
- Deploys all services to EKS
- Installs Fluent Bit for log collection

### 5. Add Slack webhook (optional)
```bash
kubectl create secret generic slack-secret \
  --from-literal=SLACK_WEBHOOK_URL=YOUR_SLACK_WEBHOOK_URL \
  -n devsecops
kubectl rollout restart deployment/ai-service -n devsecops
```

### 6. Install monitoring stack
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=devops123 \
  --set grafana.resources.requests.memory=128Mi \
  --set grafana.resources.limits.memory=256Mi \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.limits.memory=512Mi

# Expose Grafana via LoadBalancer
kubectl patch svc prometheus-grafana \
  -n monitoring \
  -p '{"spec": {"type": "LoadBalancer"}}'
```

### 7. Get service URLs
```bash
# App URL
kubectl get svc devsecops-app-service -n devsecops

# Grafana URL (admin / devops123)
kubectl get svc prometheus-grafana -n monitoring
```

---

## 🌐 Services

| Service | Type | Port | Description |
|---------|------|------|-------------|
| devsecops-app | LoadBalancer | 80 | Main FastAPI application |
| ai-service | ClusterIP | 8001 | AI anomaly detection service |
| prometheus-grafana | LoadBalancer | 80 | Grafana dashboards |

### App Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Root endpoint |
| `/health` | GET | Health check for K8s probes |
| `/api/data` | GET | Sample data with simulated latency |
| `/api/error` | GET | Simulates 500 errors for anomaly testing |

### AI Service Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | AI service health check |
| `/train` | POST | Fetch S3 logs, extract features, train model |
| `/predict` | POST | Load model, predict anomaly, fire Slack alert |

---

## ⚙️ CI/CD Pipeline

The GitHub Actions pipeline (`ci-cd.yaml`) runs on every push to `main`:

```
Push to main
     │
     ├──► Build and Scan App           (parallel, ~54s)
     │         ├── docker build
     │         ├── trivy image scan
     │         └── docker push ECR
     │
     ├──► Build and Scan AI Service    (parallel, ~1m 22s)
     │         ├── docker build
     │         ├── trivy image scan
     │         └── docker push ECR
     │
     └──► Deploy to EKS                (after both pass, ~37s)
               ├── aws eks update-kubeconfig
               ├── kubectl apply manifests
               ├── kubectl set image (rolling update)
               └── kubectl rollout status (verify)
```

### Required GitHub Secrets

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `AWS_ACCOUNT_ID` | AWS account ID (12 digits) |
| `AWS_REGION` | `us-east-1` |
| `EKS_CLUSTER_NAME` | `devsecops-cluster` |

---

## 🤖 AI Anomaly Detection

### How It Works

```
Fluent Bit (DaemonSet)
       │
       ▼ ships logs every 1 minute
   S3 Logs Bucket
       │
       ▼ POST /train
feature_engineering.py
  - fetch last 20 S3 log files
  - parse nested Fluent Bit JSON
  - extract 7 features per window
       │
       ▼
IsolationForest model
  - n_estimators=100
  - contamination=0.1
  - saved to S3 models bucket
       │
       ▼ POST /predict
  anomaly_score < -0.1
       │
       ▼
  Slack Alert 🚨
```

### Features Extracted

| Feature | Description |
|---------|-------------|
| `requests_per_window` | Total requests in log window |
| `error_rate` | Ratio of 5xx responses to total |
| `count_4xx` | Number of client error responses |
| `count_5xx` | Number of server error responses |
| `avg_latency_ms` | Mean response time in milliseconds |
| `std_latency_ms` | Standard deviation of response time |
| `unique_ips` | Number of distinct client IP addresses |

---

## 📊 Monitoring and Observability

### Grafana Access
```bash
# Get Grafana URL
kubectl get svc prometheus-grafana -n monitoring

# Open in browser — login with:
# Username: admin
# Password: devops123
```

### Available Dashboards
- **DevSecOps Platform** — Custom dashboard (auto-loaded via ConfigMap)
  - Pod CPU and memory usage per pod
  - Pod restart count and running pods
  - Node CPU and memory gauges
- **Kubernetes Cluster Overview** — Import dashboard ID `15760`

### Prometheus Access
```bash
kubectl port-forward svc/prometheus-kube-prometheus-prometheus \
  9090:9090 -n monitoring
# Open: http://localhost:9090
```

---

## 🔔 Slack Alerts

### Setup
1. Go to `https://api.slack.com/apps`
2. Create App → Enable **Incoming Webhooks**
3. Add webhook to your workspace channel
4. Add as Kubernetes secret:

```bash
kubectl create secret generic slack-secret \
  --from-literal=SLACK_WEBHOOK_URL=https://hooks.slack.com/services/XXX/XXX/XXX \
  -n devsecops
```

### Alert Types

| Alert | Trigger | Icon |
|-------|---------|------|
| Anomaly Detected | `anomaly_score < -0.1` | 🚨 |
| High Error Rate | `error_rate > 20%` | ⚠️ |
| High Latency | `avg_latency_ms > 500` | 🕐 |
| Training Complete | After successful `/train` | 🧠 |
| No Logs in S3 | Empty S3 log prefix | ❌ |

---

## 💣 Teardown

To avoid AWS charges, destroy resources in this order:

```bash
# Step 1 - Delete LoadBalancer services (prevents subnet dependency errors)
kubectl delete svc devsecops-app-service -n devsecops
kubectl delete svc prometheus-grafana -n monitoring
sleep 60

# Step 2 - Force delete ECR repositories (removes images first)
aws ecr delete-repository \
  --repository-name devsecops-app \
  --region us-east-1 --force
aws ecr delete-repository \
  --repository-name devsecops-ai-service \
  --region us-east-1 --force

# Step 3 - Destroy all infrastructure
cd terraform
terraform destroy
```

> ✅ After destroy, all AWS resources are removed and billing stops.

---

## 👤 Author

**Ankush** — [GitHub](https://github.com/Cyborg001-code)

---
