# Front end: private S3 bucket served through CloudFront.
module "frontend" {
  source = "../../modules/static_site"

  name = "doozy-web-prod"

  # Content-Security-Policy sources the app needs beyond its own origin.
  # The backend API (calls are blocked until this is set):
  csp_connect_src = var.api_origin == "" ? [] : [var.api_origin]
  # Google Fonts, loaded by doozy_web's index.html:
  csp_style_src = ["https://fonts.googleapis.com"]
  csp_font_src  = ["https://fonts.gstatic.com"]

  # Allow the microphone (for voice commands) for the site itself only;
  # deny the other features it doesn't use.
  permissions_policy = "camera=(), microphone=(self), geolocation=(), payment=(), usb=()"
}
