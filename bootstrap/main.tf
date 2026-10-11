# One-time setup: creates the S3 bucket that holds Terraform remote state for
# every environment under envs/. This configuration uses local state on
# purpose (it can't store its state in a bucket that doesn't exist yet).
# Run it once, then keep the generated terraform.tfstate somewhere safe or
# simply re-import the bucket if it is ever needed again.

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "doozy"
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}

variable "region" {
  description = "AWS region for the Terraform state bucket."
  type        = string
  default     = "us-west-2"
}

data "aws_caller_identity" "current" {}

# Bucket names are global, so the account ID is appended to keep it unique.
resource "aws_s3_bucket" "tfstate" {
  bucket = "doozy-tfstate-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Versioning lets us recover from a corrupted or accidentally deleted state.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Keep old state versions around for a while, but not forever.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

output "state_bucket_name" {
  description = "Pass this to `terraform init -backend-config=\"bucket=...\"` in envs/*."
  value       = aws_s3_bucket.tfstate.bucket
}
