resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "muchtodo-${var.environment}-jwt-secret"
  description             = "JWT secret key for ${var.environment} environment"
  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Name        = "muchtodo-${var.environment}-jwt-secret"
    SecretType  = "jwt"
    Environment = var.environment
  })
}

resource "aws_secretsmanager_secret" "mongodb_credentials" {
  name                    = "muchtodo-${var.environment}-mongodb-credentials"
  description             = "MongoDB connection credentials for ${var.environment} environment"
  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Name        = "muchtodo-${var.environment}-mongodb-credentials"
    SecretType  = "database"
    Environment = var.environment
  })
}

resource "aws_secretsmanager_secret" "redis_credentials" {
  name                    = "muchtodo-${var.environment}-redis-credentials"
  description             = "Redis password for ${var.environment} environment"
  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Name        = "muchtodo-${var.environment}-redis-credentials"
    SecretType  = "cache"
    Environment = var.environment
  })
}

resource "aws_secretsmanager_secret" "mongo_express_credentials" {
  name                    = "muchtodo-${var.environment}-mongo-express-credentials"
  description             = "Mongo Express UI credentials for ${var.environment} environment"
  recovery_window_in_days = 7

  tags = merge(var.tags, {
    Name        = "muchtodo-${var.environment}-mongo-express-credentials"
    SecretType  = "ui-tools"
    Environment = var.environment
  })
}

resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "${var.environment}-ec2-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "cloudwatch_policy" {
  name = "${var.environment}-cloudwatch-policy"
  role = aws_iam_role.ec2_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "secrets_manager_policy" {
  name = "${var.environment}-secrets-manager-policy"
  role = aws_iam_role.ec2_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.jwt_secret.arn,
          aws_secretsmanager_secret.mongodb_credentials.arn,
          aws_secretsmanager_secret.redis_credentials.arn,
          aws_secretsmanager_secret.mongo_express_credentials.arn
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_cloudwatch_role.name

  tags = var.tags
}

resource "aws_lb" "app_alb" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = var.tags
}

resource "aws_lb_target_group" "backend_tg" {
  name     = var.target_group_name
  port     = var.backend_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "backend" {
  name_prefix   = "${var.environment}-backend-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [var.backend_security_group_id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    log_group_name      = var.cloudwatch_log_group_name
    aws_region          = var.aws_region
    jwt_secret_name     = aws_secretsmanager_secret.jwt_secret.name
    mongodb_secret_name = aws_secretsmanager_secret.mongodb_credentials.name
    redis_secret_name   = aws_secretsmanager_secret.redis_credentials.name
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.environment}-backend-instance"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "backend_asg" {
  name                      = "${var.environment}-backend-asg"
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.backend_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  tag {
    key                 = "Name"
    value               = "${var.environment}-backend-asg"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "cpu_scaling" {
  name                   = "${var.environment}-cpu-scaling-policy"
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_value
  }
}

resource "aws_autoscaling_policy" "request_count_scaling" {
  name                   = "${var.environment}-request-count-scaling-policy"
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.app_alb.arn_suffix}/${aws_lb_target_group.backend_tg.arn_suffix}"
    }
    target_value = var.request_count_target_value
  }
}
