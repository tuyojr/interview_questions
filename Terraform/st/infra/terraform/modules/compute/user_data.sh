#!/bin/bash
set -e

yum update -y

yum install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/app/*.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/app.log",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/messages",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "MuchToDo/Backend",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {
            "name": "cpu_usage_idle",
            "rename": "CPU_IDLE",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "DISK_USED",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "MEM_USED",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

mkdir -p /var/log/app

yum install -y docker
systemctl start docker
systemctl enable docker

usermod -a -G docker ec2-user

mkdir -p /home/ec2-user/app
cat > /home/ec2-user/app/.env <<'EOF'
# AWS Secrets Manager Configuration
USE_SECRETS_MANAGER=true
AWS_REGION=${aws_region}
JWT_SECRET_NAME=${jwt_secret_name}
MONGODB_SECRET_NAME=${mongodb_secret_name}
REDIS_SECRET_NAME=${redis_secret_name}

# Application Configuration (non-secret)
PORT=8080
LOG_LEVEL=INFO
LOG_FORMAT=json
ENABLE_CACHE=true
DB_NAME=much_todo_db

# CORS and Security
SECURE_COOKIE=true
EOF

chown ec2-user:ec2-user /home/ec2-user/app/.env
chmod 600 /home/ec2-user/app/.env

echo "User data script completed successfully"
