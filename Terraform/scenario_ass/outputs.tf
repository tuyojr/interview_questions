output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.techcorp-vpc.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.techcorp-vpc.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.web.dns_name
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.web.arn
}

output "web_application_url" {
  description = "URL to access the web application"
  value       = "http://${aws_lb.web.dns_name}"
}

output "bastion_public_ip" {
  description = "The public IP address of the bastion host"
  value       = aws_eip.bastion-host-eip.public_ip
}

output "bastion_instance_id" {
  description = "The instance ID of the bastion host"
  value       = aws_instance.bastion-host.id
}

output "web_server_private_ips" {
  description = "Private IP addresses of web servers"
  value       = { for k, v in aws_instance.web-server : k => v.private_ip }
}

output "web_server_instance_ids" {
  description = "Instance IDs of web servers"
  value       = { for k, v in aws_instance.web-server : k => v.id }
}

output "database_private_ip" {
  description = "Private IP address of the database server"
  value       = aws_instance.database-server.private_ip
}

output "database_instance_id" {
  description = "Instance ID of the database server"
  value       = aws_instance.database-server.id
}

output "bastion_security_group_id" {
  description = "Security group ID for bastion host"
  value       = aws_security_group.bastion_sg.id
}

output "web_security_group_id" {
  description = "Security group ID for web servers"
  value       = aws_security_group.web_security_sg.id
}

output "database_security_group_id" {
  description = "Security group ID for database server"
  value       = aws_security_group.db_security_sg.id
}

output "connection_instructions" {
  description = "Instructions for connecting to the infrastructure"
  value       = <<-EOT

    =====================================================
    TechCorp Infrastructure - Connection Instructions
    =====================================================

    1. Connect to Bastion Host:
       ssh -i <your-private-key> ec2-user@${aws_eip.bastion-host-eip.public_ip}

    2. From Bastion, connect to Web Servers:
       ${join("\n       ", [for k, v in aws_instance.web-server : "ssh ec2-user@${v.private_ip}  # ${k}"])}

    3. From Bastion, connect to Database Server:
       ssh ec2-user@${aws_instance.database-server.private_ip}

    4. Access Web Application:
       URL: http://${aws_lb.web.dns_name}

    =====================================================
  EOT
}
