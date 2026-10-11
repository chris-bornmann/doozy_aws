# Front end: private S3 bucket served through CloudFront.
module "frontend" {
  source = "../../modules/static_site"

  name = "doozy-web-prod"
}
