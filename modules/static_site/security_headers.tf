# Security headers added to every response from the site.
#
# This replaces AWS's managed "SecurityHeadersPolicy", which has no
# Content-Security-Policy. A CSP matters here because the app keeps its login
# token in localStorage, where any script running on the page can read it: one
# cross-site scripting (XSS) bug, from our code or a compromised dependency,
# would let an attacker steal tokens and take over accounts. The CSP below only
# lets the browser run scripts that come from the site itself, and only talk
# to origins we list, so injected or third-party scripts can't run or send
# data anywhere.

locals {
  # Each directive limits where one kind of resource may come from.
  # 'self' means the site's own origin (the CloudFront domain).
  csp_directives = [
    # Anything not covered by a more specific directive below.
    "default-src 'self'",
    # Scripts: only the app's own bundle. No inline scripts and no eval(), which
    # is what makes injected <script> tags and event-handler attributes inert.
    "script-src 'self'",
    "style-src ${join(" ", concat(["'self'"], var.csp_style_src))}",
    "font-src ${join(" ", concat(["'self'"], var.csp_font_src))}",
    # data: allows small inline images that CSS or the browser may generate.
    "img-src 'self' data:",
    # fetch()/XHR destinations, e.g. the backend API. Also limits where stolen
    # data could be sent if a script ever did run.
    "connect-src ${join(" ", concat(["'self'"], var.csp_connect_src))}",
    # No plugins (<object>, <embed>).
    "object-src 'none'",
    # Stop injected <base> tags from redirecting the app's relative URLs.
    "base-uri 'none'",
    # Forms may only submit to the site itself.
    "form-action 'self'",
    # The site may not be shown inside another site's frame (clickjacking).
    "frame-ancestors 'none'",
    # Load any accidental http:// sub-resources over https:// instead.
    "upgrade-insecure-requests",
  ]
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "${var.name}-security-headers"
  comment = "CSP, HSTS and other security headers for ${var.name}"

  security_headers_config {
    content_security_policy {
      content_security_policy = join("; ", local.csp_directives)
      override                = true
    }

    # Browsers must use HTTPS for this site for the next year.
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
    }

    # Don't let browsers guess file types (e.g. treat an upload as a script).
    content_type_options {
      override = true
    }

    # Older-browser equivalent of frame-ancestors 'none' above.
    frame_options {
      frame_option = "DENY"
      override     = true
    }

    # Other sites only see our origin, never full URLs, in the Referer header.
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    # X-XSS-Protection, which the managed policy also sent, is deliberately
    # omitted: browsers have removed that filter, and the CSP replaces it.
  }

  # Which powerful browser features (camera, microphone, ...) the site may use.
  custom_headers_config {
    items {
      header   = "Permissions-Policy"
      value    = var.permissions_policy
      override = true
    }
  }
}
