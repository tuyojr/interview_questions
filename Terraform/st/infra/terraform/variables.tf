variable "aws_region" {
  type        = string
  description = "AWS Region for deployment"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Environment name (nonprod, prod)"
  default     = "nonprod"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR Block"
}

variable "tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
  default = {
    Org       = "muchtodo"
    ManagedBy = "terraform"
  }
}

variable "use_vault_secrets" {
  type        = bool
  description = "Whether to fetch secrets from Vault"
  default     = false
}

variable "vault_kv_mount" {
  type        = string
  description = "Vault KV secrets engine mount path"
  default     = "secret"
}

variable "vault_infra_secret_path" {
  type        = string
  description = "Path to infrastructure secrets in Vault"
  default     = "muchtodo/infrastructure"
}

variable "vault_db_secret_path" {
  type        = string
  description = "Path to database secrets in Vault"
  default     = "muchtodo/database"
}

variable "vault_ssh_secret_path" {
  type        = string
  description = "Path to SSH secrets in Vault"
  default     = "muchtodo/ssh"
}

variable "vault_backend_secret_path" {
  type        = string
  description = "Path to backend configuration secrets in Vault (used by init script)"
  default     = "muchtodo/backend"
}

variable "public_subnet_cidr" {
  description = "Public CIDR subnets"
  type        = list(string)
}

variable "public_subnet_name" {
  description = "Public subnet names"
  type        = list(string)
}

variable "public_subnet_zone" {
  description = "Availability zone for the public subnet"
  type        = list(string)
}

variable "private_subnet_cidr" {
  description = "Private CIDR subnets"
  type        = list(string)
}

variable "private_subnet_name" {
  description = "Private subnet names"
  type        = list(string)
}

variable "private_subnet_zone" {
  description = "Availability zone for the private subnet"
  type        = list(string)
}

variable "bastion_sg_name" {
  description = "Bastion security group name"
  type        = string
}

variable "bastion_ingress_ip" {
  description = "Bastion security group allowed IP (CIDR format)"
  type        = string
}

variable "web_sg_name" {
  description = "Web security group name"
  type        = string
}

variable "web_sg_ports" {
  description = "Web security group allowed ports"
  type        = list(number)
}

variable "db_sg_name" {
  description = "Database security group name"
  type        = string
}

variable "alb_sg_name" {
  description = "ALB security group name"
  type        = string
  default     = "alb_security_group"
}

variable "common_instance_type" {
  description = "Instance type for the bastion host and Web server"
  type        = string
}

variable "db_instance_type" {
  description = "Instance type for the Database server"
  type        = string
}

variable "bastion-key" {
  description = "Key Pair name for the bastion host"
  type        = string
}

variable "bastion-pub-key" {
  description = "Public key used for creating the bastion host key pair"
  type        = string
  default     = ""
}

variable "alb_name" {
  description = "Name for the Application Load Balancer"
  type        = string
  default     = "muchtodo-alb"
}

variable "target_group_name" {
  description = "Name for the ALB target group"
  type        = string
  default     = "muchtodo-web-tg"
}

variable "health_check_path" {
  description = "Health check path for ALB"
  type        = string
  default     = "/"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks"
  type        = number
  default     = 2
}

variable "backend_port" {
  description = "Port on which backend application runs"
  type        = number
  default     = 8080
}

# Auto Scaling Group Variables
variable "asg_min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for scaling"
  type        = number
  default     = 70
}

variable "request_count_target_value" {
  description = "Target request count per instance for scaling"
  type        = number
  default     = 1000
}

# Storage Module Variables
variable "frontend_bucket_name" {
  description = "Name for the S3 bucket hosting the frontend"
  type        = string
}

variable "cloudfront_price_class" {
  description = "CloudFront distribution price class"
  type        = string
  default     = "PriceClass_100"
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes in the cluster"
  type        = number
  default     = 1
}

variable "redis_parameter_group_name" {
  description = "Parameter group name for Redis"
  type        = string
  default     = "default.redis7"
}

# Monitoring Module Variables
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
}

variable "alb_response_time_threshold" {
  description = "Threshold for ALB response time alarm (seconds)"
  type        = number
  default     = 2
}

variable "cpu_high_threshold" {
  description = "Threshold for CPU high alarm (percentage)"
  type        = number
  default     = 80
}
