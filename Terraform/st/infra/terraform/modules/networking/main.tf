locals {
  az_to_public_subnet = {
    for idx, az in var.public_subnet_zone :
    az => var.public_subnet_name[idx]
  }

  private_subnet_to_az = {
    for idx, name in var.private_subnet_name :
    name => var.private_subnet_zone[idx]
  }
}

resource "aws_vpc" "muchtodo-vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "muchtodo-vpc"
  })
}

resource "aws_subnet" "public" {
  for_each = {
    for idx, cidr in var.public_subnet_cidr :
    var.public_subnet_name[idx] => {
      cidr = cidr
      az   = var.public_subnet_zone[idx]
    }
  }

  vpc_id                  = aws_vpc.muchtodo-vpc.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = each.key
  })

  depends_on = [aws_internet_gateway.muchtodo-gw]
}

resource "aws_subnet" "private" {
  for_each = {
    for idx, cidr in var.private_subnet_cidr :
    var.private_subnet_name[idx] => {
      cidr = cidr
      az   = var.private_subnet_zone[idx]
    }
  }

  vpc_id            = aws_vpc.muchtodo-vpc.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.tags, {
    Name = each.key
  })

  depends_on = [aws_internet_gateway.muchtodo-gw]
}

resource "aws_internet_gateway" "muchtodo-gw" {
  vpc_id = aws_vpc.muchtodo-vpc.id

  tags = merge(var.tags, {
    Name = "muchtodo-igw"
  })
}

resource "aws_eip" "muchtodo-eip" {
  for_each = aws_subnet.public
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "muchtodo-eip-${each.key}"
  })
}

resource "aws_nat_gateway" "muchtodo-nat-gw" {
  for_each      = aws_subnet.public
  allocation_id = aws_eip.muchtodo-eip[each.key].id
  subnet_id     = each.value.id

  tags = merge(var.tags, {
    Name = "muchtodo-nat-${each.key}"
  })

  depends_on = [aws_internet_gateway.muchtodo-gw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.muchtodo-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.muchtodo-gw.id
  }

  tags = merge(var.tags, {
    Name = "muchtodo-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.muchtodo-vpc.id

  tags = merge(var.tags, {
    Name = "muchtodo-private-rt-${each.key}"
  })
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route" "private_nat" {
  for_each               = aws_subnet.private
  route_table_id         = aws_route_table.private[each.key].id
  nat_gateway_id         = aws_nat_gateway.muchtodo-nat-gw[local.az_to_public_subnet[local.private_subnet_to_az[each.key]]].id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_security_group" "bastion_sg" {
  name        = var.bastion_sg_name
  description = "Allow SSH from current IP"
  vpc_id      = aws_vpc.muchtodo-vpc.id

  tags = merge(var.tags, {
    Name = var.bastion_sg_name
  })
}

resource "aws_vpc_security_group_ingress_rule" "bastion_sg_allow_ssh" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = var.bastion_ingress_ip
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "bastion_sg_allow_all_egress" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "web_security_sg" {
  name        = var.web_sg_name
  description = "Allow HTTP and HTTPS from anywhere, and SSH from bastion only"
  vpc_id      = aws_vpc.muchtodo-vpc.id

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "web_security_sg_http_ingress" {
  for_each = {
    for port in var.web_sg_ports : port => port
  }
  security_group_id = aws_security_group.web_security_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = each.value
  ip_protocol       = "tcp"
  to_port           = each.value
}

resource "aws_vpc_security_group_ingress_rule" "web_security_sg_ssh_ingress" {
  security_group_id            = aws_security_group.web_security_sg.id
  referenced_security_group_id = aws_security_group.bastion_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "web_security_sg_allow_all_egress" {
  security_group_id = aws_security_group.web_security_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "db_security_sg" {
  name        = var.db_sg_name
  description = "Allow MySQL/PostgreSQL from Web SG, and SSH from bastion only"
  vpc_id      = aws_vpc.muchtodo-vpc.id

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "db_security_sg_mysql_ingress" {
  security_group_id            = aws_security_group.db_security_sg.id
  referenced_security_group_id = aws_security_group.web_security_sg.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}

resource "aws_vpc_security_group_ingress_rule" "db_security_sg_postgres_ingress" {
  security_group_id            = aws_security_group.db_security_sg.id
  referenced_security_group_id = aws_security_group.web_security_sg.id
  from_port                    = 5432
  ip_protocol                  = "tcp"
  to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "db_security_sg_ssh_ingress" {
  security_group_id            = aws_security_group.db_security_sg.id
  referenced_security_group_id = aws_security_group.bastion_sg.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "db_security_sg_allow_all_egress" {
  security_group_id = aws_security_group.db_security_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "alb_sg" {
  name        = var.alb_sg_name
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.muchtodo-vpc.id

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "alb_http_ingress" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "alb_https_ingress" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_sg_allow_all_egress" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
