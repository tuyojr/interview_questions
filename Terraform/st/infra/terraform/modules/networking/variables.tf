variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "public_subnet_name" {
  description = "List of names for public subnets"
  type        = list(string)
}

variable "public_subnet_zone" {
  description = "List of availability zones for public subnets"
  type        = list(string)
}

variable "private_subnet_cidr" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}

variable "private_subnet_name" {
  description = "List of names for private subnets"
  type        = list(string)
}

variable "private_subnet_zone" {
  description = "List of availability zones for private subnets"
  type        = list(string)
}

variable "bastion_sg_name" {
  description = "Name for bastion security group"
  type        = string
}

variable "bastion_ingress_ip" {
  description = "CIDR block allowed to SSH into bastion"
  type        = string
}

variable "web_sg_name" {
  description = "Name for web security group"
  type        = string
}

variable "web_sg_ports" {
  description = "List of ports to allow in web security group"
  type        = list(number)
}

variable "db_sg_name" {
  description = "Name for database security group"
  type        = string
}

variable "alb_sg_name" {
  description = "Name for ALB security group"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
