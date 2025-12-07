terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    # Backend configuration is provided via:
    # 1. -backend-config file (nonprod-backend.tfvars)
    # 2. Environment variables set by the init script (from Vault)
    #
    # The bucket name comes from Vault and is passed via:
    # terraform init -backend-config="bucket=$BUCKET_NAME" -backend-config=nonprod-backend.tfvars
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.20.0"
    }
  }
}
