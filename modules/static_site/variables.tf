variable "name" {
  description = "Base name for the site's resources, e.g. \"doozy-web-prod\". The account ID is appended to the bucket name to make it globally unique."
  type        = string
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_100 (North America + Europe edges) is the cheapest."
  type        = string
  default     = "PriceClass_100"
}

variable "noncurrent_version_retention_days" {
  description = "How long to keep previous versions of deployed files (for rollback) before S3 deletes them."
  type        = number
  default     = 30
}
