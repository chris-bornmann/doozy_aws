output "bucket_name" {
  description = "S3 bucket to upload the built front end (dist/) into."
  value       = aws_s3_bucket.site.bucket
}

output "bucket_arn" {
  description = "ARN of the site bucket."
  value       = aws_s3_bucket.site.arn
}

output "distribution_id" {
  description = "CloudFront distribution ID (needed for cache invalidations)."
  value       = aws_cloudfront_distribution.site.id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution."
  value       = aws_cloudfront_distribution.site.arn
}

output "site_url" {
  description = "Public URL of the site."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "content_security_policy" {
  description = "The Content-Security-Policy header the site is served with."
  value       = aws_cloudfront_response_headers_policy.security.security_headers_config[0].content_security_policy[0].content_security_policy
}
