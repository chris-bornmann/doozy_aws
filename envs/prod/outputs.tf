output "site_url" {
  description = "Public URL of the front end."
  value       = module.frontend.site_url
}

output "frontend_bucket_name" {
  description = "Bucket to sync dist/ into (GitHub variable FRONTEND_BUCKET)."
  value       = module.frontend.bucket_name
}

output "frontend_distribution_id" {
  description = "CloudFront distribution ID (GitHub variable FRONTEND_DISTRIBUTION_ID)."
  value       = module.frontend.distribution_id
}

output "frontend_deploy_role_arn" {
  description = "IAM role for GitHub Actions to assume (GitHub variable AWS_DEPLOY_ROLE_ARN)."
  value       = aws_iam_role.frontend_deploy.arn
}
