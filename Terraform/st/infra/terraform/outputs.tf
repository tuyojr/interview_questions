# Networking Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.networking.private_subnet_ids
}

# Compute Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "alb_url" {
  description = "URL of the Application Load Balancer"
  value       = "http://${module.compute.alb_dns_name}"
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.asg_name
}

# Storage Outputs
output "frontend_bucket_name" {
  description = "Name of the S3 bucket for frontend"
  value       = module.storage.frontend_bucket_name
}

output "frontend_bucket_website_endpoint" {
  description = "Website endpoint of the S3 bucket"
  value       = module.storage.frontend_bucket_website_endpoint
}

output "frontend_url" {
  description = "URL to access the frontend via S3"
  value       = "http://${module.storage.frontend_bucket_website_endpoint}"
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.storage.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.storage.cloudfront_domain_name
}

output "cloudfront_url" {
  description = "URL to access the frontend via CloudFront"
  value       = "https://${module.storage.cloudfront_domain_name}"
}

output "redis_cluster_address" {
  description = "Address of the Redis cluster"
  value       = module.storage.redis_cluster_address
}

output "redis_cluster_port" {
  description = "Port of the Redis cluster"
  value       = module.storage.redis_cluster_port
}

output "redis_connection_string" {
  description = "Redis connection string"
  value       = "${module.storage.redis_cluster_address}:${module.storage.redis_cluster_port}"
}

# Secrets Outputs
output "secrets_info" {
  description = "AWS Secrets Manager secret names"
  value = {
    jwt_secret                = module.compute.jwt_secret_name
    mongodb_credentials       = module.compute.mongodb_secret_name
    redis_credentials         = module.compute.redis_secret_name
    mongo_express_credentials = module.compute.mongo_express_secret_name
  }
}

# Monitoring Outputs
output "backend_log_group_name" {
  description = "Name of the backend CloudWatch log group"
  value       = module.monitoring.backend_log_group_name
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_name
}

# Deployment Information
output "deployment_info" {
  description = "Summary of deployment information"
  value = {
    environment         = var.environment
    region              = var.aws_region
    backend_url         = "http://${module.compute.alb_dns_name}"
    frontend_cloudfront = "https://${module.storage.cloudfront_domain_name}"
    frontend_s3         = "http://${module.storage.frontend_bucket_website_endpoint}"
    redis_endpoint      = "${module.storage.redis_cluster_address}:${module.storage.redis_cluster_port}"
  }
}
