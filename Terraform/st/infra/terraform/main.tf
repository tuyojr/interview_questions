terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28.0"
    }
  }

  backend "s3" {
    bucket       = "muchtodo-terraform-state"
    key          = "infra/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

module "networking" {
  source = "./modules/networking"

  vpc_cidr_block      = var.vpc_cidr_block
  public_subnet_cidr  = var.public_subnet_cidr
  public_subnet_name  = var.public_subnet_name
  public_subnet_zone  = var.public_subnet_zone
  private_subnet_cidr = var.private_subnet_cidr
  private_subnet_name = var.private_subnet_name
  private_subnet_zone = var.private_subnet_zone

  bastion_sg_name    = var.bastion_sg_name
  bastion_ingress_ip = var.bastion_ingress_ip
  web_sg_name        = var.web_sg_name
  web_sg_ports       = var.web_sg_ports
  db_sg_name         = var.db_sg_name
  alb_sg_name        = var.alb_sg_name

  tags = var.tags
}

module "storage" {
  source = "./modules/storage"

  environment                = var.environment
  vpc_id                     = module.networking.vpc_id
  private_subnet_ids         = module.networking.private_subnet_ids
  backend_security_group_id  = module.networking.web_sg_id
  frontend_bucket_name       = var.frontend_bucket_name
  cloudfront_price_class     = var.cloudfront_price_class
  redis_engine_version       = var.redis_engine_version
  redis_node_type            = var.redis_node_type
  redis_num_cache_nodes      = var.redis_num_cache_nodes
  redis_parameter_group_name = var.redis_parameter_group_name

  tags = var.tags
}

module "compute" {
  source = "./modules/compute"

  environment                      = var.environment
  aws_region                       = var.aws_region
  vpc_id                           = module.networking.vpc_id
  public_subnet_ids                = module.networking.public_subnet_ids
  private_subnet_ids               = module.networking.private_subnet_ids
  alb_security_group_id            = module.networking.alb_sg_id
  backend_security_group_id        = module.networking.web_sg_id
  alb_name                         = var.alb_name
  target_group_name                = var.target_group_name
  backend_port                     = var.backend_port
  health_check_path                = var.health_check_path
  health_check_interval            = var.health_check_interval
  health_check_timeout             = var.health_check_timeout
  health_check_healthy_threshold   = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold
  instance_type                    = var.common_instance_type
  key_name                         = var.bastion-key
  asg_min_size                     = var.asg_min_size
  asg_max_size                     = var.asg_max_size
  asg_desired_capacity             = var.asg_desired_capacity
  cpu_target_value                 = var.cpu_target_value
  request_count_target_value       = var.request_count_target_value
  cloudwatch_log_group_name        = "/aws/ec2/${var.environment}/backend"

  tags = var.tags
}

module "monitoring" {
  source = "./modules/monitoring"

  environment                 = var.environment
  aws_region                  = var.aws_region
  log_retention_days          = var.log_retention_days
  alb_arn_suffix              = element(split("loadbalancer/", module.compute.alb_arn), 1)
  target_group_arn_suffix     = element(split(":", module.compute.target_group_arn), 5)
  asg_name                    = module.compute.asg_name
  alb_response_time_threshold = var.alb_response_time_threshold
  cpu_high_threshold          = var.cpu_high_threshold

  tags = var.tags
}
