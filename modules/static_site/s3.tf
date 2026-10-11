data "aws_caller_identity" "current" {}

# Private bucket holding the built front end (the contents of `dist/`).
# It is never public: only the CloudFront distribution can read from it.
# Access logging is off on purpose: it adds storage/request cost and isn't needed yet.
#trivy:ignore:AWS-0089
resource "aws_s3_bucket" "site" {
  bucket = "${var.name}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# SSE-S3 (AES256) instead of a customer-managed KMS key: KMS costs $1/key/month
# plus per-request fees, and this data doesn't need customer-controlled keys.
#trivy:ignore:AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning keeps the previous deploy's files so a bad release can be rolled back.
resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Old versions are only useful for a short while; expire them to keep storage costs at ~zero.
resource "aws_s3_bucket_lifecycle_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  # Lifecycle rules on versioned buckets must be applied after versioning is enabled.
  depends_on = [aws_s3_bucket_versioning.site]
}

# Allow reads only from this specific CloudFront distribution (via Origin Access Control).
data "aws_iam_policy_document" "site" {
  statement {
    sid       = "AllowCloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json

  # Make sure Block Public Access is in place before any policy is attached.
  depends_on = [aws_s3_bucket_public_access_block.site]
}
