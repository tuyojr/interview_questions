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
    Org       = "techcorp"
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
  default     = "techcorp/infrastructure"
}

variable "vault_db_secret_path" {
  type        = string
  description = "Path to database secrets in Vault"
  default     = "techcorp/database"
}

variable "vault_ssh_secret_path" {
  type        = string
  description = "Path to SSH secrets in Vault"
  default     = "techcorp/ssh"
}

variable "vault_backend_secret_path" {
  type        = string
  description = "Path to backend configuration secrets in Vault (used by init script)"
  default     = "techcorp/backend"
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
  default     = "techcorp-alb"
}

variable "target_group_name" {
  description = "Name for the ALB target group"
  type        = string
  default     = "techcorp-web-tg"
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
