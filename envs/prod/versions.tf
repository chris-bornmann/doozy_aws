terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state in the bucket created by bootstrap/. The bucket name contains
  # the AWS account ID, so it is supplied at init time:
  #   terraform init -backend-config="bucket=doozy-tfstate-<account-id>"
  # use_lockfile enables S3-native state locking (no DynamoDB table needed).
  backend "s3" {
    key          = "prod/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "doozy"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}
