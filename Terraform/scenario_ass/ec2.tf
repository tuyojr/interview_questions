
data "aws_ami" "amazon-linux-2" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_key_pair" "bastion-host-key-pair" {
  key_name   = var.bastion-key
  public_key = local.bastion_public_key
}

resource "aws_instance" "bastion-host" {
  ami                    = data.aws_ami.amazon-linux-2.id
  instance_type          = var.common_instance_type
  subnet_id              = aws_subnet.public[var.public_subnet_name[0]].id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = aws_key_pair.bastion-host-key-pair.key_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  tags = var.tags
}

resource "aws_eip" "bastion-host-eip" {
  instance = aws_instance.bastion-host.id
  domain   = "vpc"

  tags = var.tags
}

resource "aws_instance" "web-server" {
  for_each                    = aws_subnet.private
  ami                         = data.aws_ami.amazon-linux-2.id
  instance_type               = var.common_instance_type
  subnet_id                   = each.value.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.web_security_sg.id]
  key_name                    = aws_key_pair.bastion-host-key-pair.key_name
  user_data                   = file("${path.module}/httpd.sh")

  tags = var.tags

  depends_on = [aws_nat_gateway.techcorp-nat-gw]
}

resource "aws_instance" "database-server" {
  ami                    = data.aws_ami.amazon-linux-2.id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.private[var.private_subnet_name[0]].id
  vpc_security_group_ids = [aws_security_group.db_security_sg.id]
  key_name               = aws_key_pair.bastion-host-key-pair.key_name
  user_data              = base64encode(templatefile("${path.module}/postgres.sh", {
    db_name     = local.db_name
    db_user     = local.db_username
    db_password = local.db_password
  }))

  tags = var.tags

  depends_on = [aws_nat_gateway.techcorp-nat-gw]
}

resource "aws_lb" "web" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = false

  tags = var.tags
}

resource "aws_lb_target_group" "web" {
  name     = var.target_group_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.techcorp-vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = var.health_check_interval
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = var.tags
}

resource "aws_lb_target_group_attachment" "web" {
  for_each         = aws_instance.web-server
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = each.value.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
