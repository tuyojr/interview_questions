# MuchToDo Infrastructure - Terraform

This directory contains Terraform configurations for deploying the MuchToDo application infrastructure on AWS.

## Architecture Overview

The infrastructure consists of four main modules:

1. **Networking Module**: VPC, subnets, NAT gateways, security groups
2. **Compute Module**: ALB, Auto Scaling Group, EC2 instances
3. **Storage Module**: S3, CloudFront, ElastiCache Redis
4. **Monitoring Module**: CloudWatch logs, alarms, and dashboards

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- An S3 bucket for Terraform state (referenced in backend configuration)
- SSH key pair created in AWS (for EC2 instances)

## Quick Start

### 1. Configure Backend

Update the S3 backend configuration in `main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket       = "your-terraform-state-bucket"
    key          = "infra/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

### 2. Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values:

- Update `bastion_ingress_ip` with your IP address
- Change `frontend_bucket_name` to a globally unique name
- Adjust instance types and scaling parameters as needed

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan and Apply

```bash
# Review the plan
terraform plan

# Apply the infrastructure
terraform apply
```

### 5. Access Outputs

After successful deployment:

```bash
# View all outputs
terraform output

# View specific output
terraform output alb_url
terraform output cloudfront_url
```

## Module Structure

```TEXT
terraform/
├── main.tf                 # Root module configuration
├── variables.tf            # Root module variables
├── outputs.tf              # Root module outputs
├── terraform.tfvars        # Variable values (gitignored)
├── terraform.tfvars.example # Example variable values
├── README.md               # This file
└── modules/
    ├── networking/         # VPC and networking resources
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    ├── compute/            # EC2, ASG, ALB resources
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── user_data.sh
    │   └── README.md
    ├── storage/            # S3, CloudFront, Redis resources
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    └── monitoring/         # CloudWatch resources
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── README.md
```

## Important Variables

### Required Variables

| Variable | Description | Example |
| ---------- | ------------- | --------- |
| `vpc_cidr_block` | CIDR block for VPC | `10.0.0.0/16` |
| `public_subnet_cidr` | Public subnet CIDRs | `["10.0.1.0/24", "10.0.2.0/24"]` |
| `private_subnet_cidr` | Private subnet CIDRs | `["10.0.11.0/24", "10.0.12.0/24"]` |
| `bastion-key` | SSH key pair name | `muchtodo-key` |
| `frontend_bucket_name` | S3 bucket name (must be unique) | `muchtodo-frontend-prod-xyz123` |

### Optional Variables

| Variable | Description | Default |
| ---------- | ------------- | --------- |
| `environment` | Environment name | `nonprod` |
| `aws_region` | AWS region | `us-east-1` |
| `asg_min_size` | Minimum ASG instances | `1` |
| `asg_max_size` | Maximum ASG instances | `4` |
| `redis_node_type` | Redis instance type | `cache.t3.micro` |

## Outputs

The root module exposes these key outputs:

- `alb_url` - Application Load Balancer URL
- `cloudfront_url` - CloudFront distribution URL
- `redis_connection_string` - Redis endpoint for application configuration
- `backend_log_group_name` - CloudWatch log group for backend logs

## State Management

### Backend Configuration

This configuration uses S3 for remote state storage with state locking enabled:

```hcl
backend "s3" {
  bucket       = "muchtodo-terraform-state"
  key          = "infra/terraform.tfstate"
  region       = "us-east-1"
  encrypt      = true
  use_lockfile = true
}
```

### State Locking

State locking is enabled via the `use_lockfile` option to prevent concurrent modifications.

## Security Best Practices

1. **Bastion Access**: Update `bastion_ingress_ip` to your specific IP address
2. **Secrets Management**: Never commit `terraform.tfvars` to version control
3. **State Encryption**: S3 backend encryption is enabled
4. **Security Groups**: Follow principle of least privilege
5. **Private Subnets**: Backend instances are in private subnets
6. **IMDSv2**: Launch template enforces IMDSv2 for EC2 metadata

## Cost Optimization

- NAT Gateways are the most expensive resources (~$32/month each)
- Consider using a single NAT gateway for non-production environments
- ElastiCache Redis uses t3.micro for cost efficiency
- CloudWatch logs retention set to 7 days by default

## Troubleshooting

### Common Issues

1. **State Locking Error**
   - Ensure S3 bucket exists and you have permissions
   - Check if another user is running Terraform

2. **Subnet CIDR Conflicts**
   - Verify subnet CIDRs don't overlap
   - Ensure subnets fit within VPC CIDR

3. **CloudFront Deployment**
   - CloudFront takes 15-20 minutes to deploy
   - Check CloudFront console for distribution status

4. **Health Check Failures**
   - Verify backend application is responding on the configured port
   - Check security group rules allow ALB to reach instances

## Maintenance

### Updating Infrastructure

```bash
# Pull latest changes
git pull

# Plan changes
terraform plan

# Apply changes
terraform apply
```

### Destroying Infrastructure

```bash
# CAUTION: This will destroy all resources
terraform destroy
```

Before destroying:

- Backup any important data
- Download CloudWatch logs if needed
- Empty S3 buckets (required for deletion)

## Module Documentation

For detailed information about each module, see their respective README files:

- [Networking Module](./modules/networking/README.md)
- [Compute Module](./modules/compute/README.md)
- [Storage Module](./modules/storage/README.md)
- [Monitoring Module](./modules/monitoring/README.md)

## Contributing

When making changes:

1. Update module README if inputs/outputs change
2. Run `terraform fmt` to format code
3. Run `terraform validate` to check syntax
4. Test changes in a non-production environment first
5. Document any breaking changes

## Support

For issues or questions:

- Check module READMEs for specific module issues
- Review AWS CloudWatch logs for runtime issues
- Check Terraform state for resource details
