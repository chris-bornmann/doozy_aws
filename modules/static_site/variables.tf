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

variable "csp_connect_src" {
  description = "Extra origins the site may contact with fetch/XHR (Content-Security-Policy connect-src), e.g. the backend API: [\"https://api.example.com\"]. The site's own origin is always allowed."
  type        = list(string)
  default     = []
}

variable "csp_style_src" {
  description = "Extra origins the site may load stylesheets from (Content-Security-Policy style-src). The site's own origin is always allowed."
  type        = list(string)
  default     = []
}

variable "csp_font_src" {
  description = "Extra origins the site may load fonts from (Content-Security-Policy font-src). The site's own origin is always allowed."
  type        = list(string)
  default     = []
}

variable "permissions_policy" {
  description = "Value of the Permissions-Policy header: which powerful browser features the site may use. The default denies all of the common ones."
  type        = string
  default     = "camera=(), microphone=(), geolocation=(), payment=(), usb=()"
}
