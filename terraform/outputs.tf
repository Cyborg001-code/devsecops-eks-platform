output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "eks_cluster_name" {
  description = "EKS Cluster name"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS Cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "ecr_app_repository_url" {
  description = "ECR repository URL for app"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_ai_service_repository_url" {
  description = "ECR repository URL for AI service"
  value       = aws_ecr_repository.ai_service.repository_url
}

output "s3_logs_bucket" {
  description = "S3 bucket name for logs"
  value       = aws_s3_bucket.logs.bucket
}

output "s3_models_bucket" {
  description = "S3 bucket name for ML models"
  value       = aws_s3_bucket.models.bucket
}