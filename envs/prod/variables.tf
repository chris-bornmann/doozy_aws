variable "region" {
  description = "AWS region for regional resources (the site bucket)."
  type        = string
  default     = "us-west-2"
}

variable "budget_alert_email" {
  description = "Email address that receives AWS budget alerts."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly AWS spend (USD) above which an alert is emailed."
  type        = number
  default     = 5
}

variable "github_repository" {
  description = "GitHub repo (owner/name) whose workflows may deploy the front end."
  type        = string
  default     = "chris-bornmann/doozy_web"
}

variable "github_deploy_branch" {
  description = "Only workflows running on this branch may assume the deploy role."
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set to false if the AWS account already has one (only one is allowed per account)."
  type        = bool
  default     = true
}
