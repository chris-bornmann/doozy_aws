# TFLint configuration, shared by every Terraform root in this repo.
# CI runs `tflint --recursive` from the repo root, which applies this file
# to bootstrap/, envs/*, and (through `call_module_type`) modules/.

config {
  call_module_type = "local"
}

# General Terraform best practices (naming, unused declarations, pinned versions, ...).
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS-specific checks, e.g. invalid instance types or regions.
plugin "aws" {
  enabled = true
  version = "0.49.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
