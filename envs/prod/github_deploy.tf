# Lets GitHub Actions in the doozy_web repo deploy the built site without any
# long-lived AWS keys: the workflow exchanges its GitHub OIDC token for
# short-lived credentials of the role below.

locals {
  github_oidc_url = "token.actions.githubusercontent.com"

  # Use the provider created here, or the one that already exists in the account.
  github_oidc_provider_arn = (
    var.create_github_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : data.aws_iam_openid_connect_provider.github[0].arn
  )
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://${local.github_oidc_url}"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1

  url = "https://${local.github_oidc_url}"
}

# Only workflows from the given repo *and* branch can assume the role.
data "aws_iam_policy_document" "frontend_deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc_url}:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/${var.github_deploy_branch}"]
    }
  }
}

resource "aws_iam_role" "frontend_deploy" {
  name                 = "doozy-web-prod-deploy"
  description          = "Assumed by GitHub Actions in ${var.github_repository} to deploy the front end."
  assume_role_policy   = data.aws_iam_policy_document.frontend_deploy_trust.json
  max_session_duration = 3600
}

# Least privilege: sync files into the site bucket and invalidate its distribution.
data "aws_iam_policy_document" "frontend_deploy" {
  statement {
    sid       = "ListSiteBucket"
    actions   = ["s3:ListBucket"]
    resources = [module.frontend.bucket_arn]
  }

  statement {
    sid       = "WriteSiteObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${module.frontend.bucket_arn}/*"]
  }

  statement {
    sid       = "InvalidateCdn"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [module.frontend.distribution_arn]
  }
}

resource "aws_iam_role_policy" "frontend_deploy" {
  name   = "deploy-frontend"
  role   = aws_iam_role.frontend_deploy.id
  policy = data.aws_iam_policy_document.frontend_deploy.json
}
