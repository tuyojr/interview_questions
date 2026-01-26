output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.app_alb.arn
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.app_alb.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.backend_tg.arn
}

output "jwt_secret_name" {
  description = "Name of the JWT secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.jwt_secret.name
}

output "mongodb_secret_name" {
  description = "Name of the MongoDB credentials secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.mongodb_credentials.name
}

output "redis_secret_name" {
  description = "Name of the Redis credentials secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.redis_credentials.name
}

output "mongo_express_secret_name" {
  description = "Name of the Mongo Express credentials secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.mongo_express_credentials.name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.backend_asg.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.backend_asg.arn
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.backend.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role for EC2 instances"
  value       = aws_iam_role.ec2_cloudwatch_role.arn
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}
