# AWS-managed policy: caching tuned for static files.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# Lets CloudFront sign its requests to the private bucket.
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = var.name
  description                       = "Access to the ${var.name} S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  s3_origin_id = "s3-${var.name}"
}

# Logging and WAF are off on purpose to keep the bill at ~$0: WAF is ~$5/month
# plus per-request fees, and this only serves public static files.
#trivy:ignore:AWS-0010
#trivy:ignore:AWS-0011
resource "aws_cloudfront_distribution" "site" {
  comment             = var.name
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = var.price_class
  default_root_object = "index.html"

  origin {
    origin_id                = local.s3_origin_id
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id           = local.s3_origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # The app uses client-side routing (react-router's BrowserRouter), so a
  # request for e.g. /items or /auth/callback has no matching file in S3.
  # S3 answers 403 for missing keys when the caller can't list the bucket
  # (and 404 if it can), so both are mapped to index.html with a 200 and the
  # React router takes it from there.
  #
  # NOTE: when the backend API is later served through this distribution,
  # these rules would also rewrite real API errors. At that point switch to
  # a CloudFront Function that rewrites only extension-less, non-/api paths.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # No custom domain yet, so use the free *.cloudfront.net certificate.
  # When a domain is added, use an ACM certificate (in us-east-1) with
  # ssl_support_method = "sni-only" -- never "vip", which costs ~$600/month.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
