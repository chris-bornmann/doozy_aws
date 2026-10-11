# doozy_aws

Terraform for hosting Doozy on AWS (region `us-west-2`).

So far this covers the **front end** ([doozy_web](https://github.com/chris-bornmann/doozy_web)):
a private S3 bucket served through CloudFront. The back end (ECS) will be added later.

```
Browser ──HTTPS──▶ CloudFront ──(Origin Access Control)──▶ private S3 bucket
```

## Layout

| Path | What it is |
|---|---|
| `bootstrap/` | One-time setup: the S3 bucket that stores Terraform state. Uses local state. |
| `modules/static_site/` | Reusable module: private S3 bucket + CloudFront distribution for a single-page app. |
| `envs/prod/` | The production environment: the front end, a monthly budget alarm, and an IAM role GitHub Actions can use to deploy. |

## Prerequisites

- Terraform >= 1.10 (needed for S3-native state locking)
- AWS credentials for the target account in your shell (e.g. `aws configure` / `AWS_PROFILE`)

## First-time setup

1. **Create the state bucket** (once per AWS account):

   ```sh
   cd bootstrap
   terraform init
   terraform apply
   ```

   Note the `state_bucket_name` output (`doozy-tfstate-<account-id>`).

2. **Configure the prod environment:**

   ```sh
   cd ../envs/prod
   cp terraform.tfvars.example terraform.tfvars   # then set budget_alert_email
   terraform init -backend-config="bucket=doozy-tfstate-<account-id>"
   terraform apply
   ```

   Commit the generated `.terraform.lock.hcl` files.

   If the account already has GitHub's OIDC provider (`token.actions.githubusercontent.com`),
   set `create_github_oidc_provider = false` in `terraform.tfvars`.

3. **(Recommended) Switch the distribution to the CloudFront flat-rate *Free* plan.**
   It caps the bill at $0 (traffic beyond the plan's allowance is throttled, not billed).
   The Terraform AWS provider can't manage pricing plans yet, so do this once in the
   console: *CloudFront → Distributions → (the distribution) → Pricing plan*.
   If a later `terraform plan` shows unexpected changes to the distribution, check
   whether they come from the plan switch before applying.

## Deploying the front end

Terraform only creates the infrastructure; the built site is uploaded separately.
The values below come from `terraform output` in `envs/prod`.

```sh
cd doozy_web
VITE_API_BASE_URL=<backend url> npm run build

BUCKET=$(terraform -chdir=../doozy_aws/envs/prod output -raw frontend_bucket_name)
DIST=$(terraform -chdir=../doozy_aws/envs/prod output -raw frontend_distribution_id)

# 1. Upload new hashed assets first. They never change, so cache them for a year.
aws s3 sync dist/assets "s3://$BUCKET/assets" \
  --cache-control "public,max-age=31536000,immutable"

# 2. Then index.html etc., which must be re-checked on every load.
aws s3 sync dist "s3://$BUCKET" --delete --exclude "assets/*" \
  --cache-control "no-cache"
aws cloudfront create-invalidation --distribution-id "$DIST" --paths "/index.html"

# 3. Finally remove assets the new index.html no longer references.
#    (Doing this last avoids breaking pages that are mid-load during the deploy.)
aws s3 sync dist/assets "s3://$BUCKET/assets" --delete \
  --cache-control "public,max-age=31536000,immutable"
```

The site is then live at the `site_url` output.

### From GitHub Actions

`envs/prod` also creates an IAM role (`frontend_deploy_role_arn` output) that
workflows on `main` in `chris-bornmann/doozy_web` can assume via OIDC, with
permission only to sync the bucket and invalidate the distribution. Set these
repository variables in doozy_web: `AWS_DEPLOY_ROLE_ARN`, `FRONTEND_BUCKET`,
`FRONTEND_DISTRIBUTION_ID`, and use `aws-actions/configure-aws-credentials`
with `role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}`.

## Cost notes

- At hobby traffic the front end should cost ~$0 (CloudFront free allowance / flat-rate Free plan,
  plus pennies of S3 storage).
- `envs/prod/budget.tf` emails `budget_alert_email` when monthly spend for the **whole account**
  reaches 80% of `monthly_budget_usd` (default $5), or is forecast to exceed it.
- Things deliberately *not* used because they cost money: WAF, Lambda@Edge, logging,
  Origin Shield, dedicated-IP SSL. `PriceClass_100` limits edges to North America and Europe.

## When the back end arrives

- The back end's CORS `origins` list (`doozy/src/app/main.py`) must include the `site_url`.
- The front end must be built with `VITE_API_BASE_URL` pointing at the API.
- If the API is served through this same CloudFront distribution (e.g. `/api/*`), replace the
  403/404 → `index.html` error mapping in `modules/static_site/cloudfront.tf` with a
  CloudFront Function, so real API errors aren't rewritten.
