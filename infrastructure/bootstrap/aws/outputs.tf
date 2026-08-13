# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "bucket" {
  value       = aws_s3_bucket.state.id
  description = "Name of the state bucket."
}

output "region" {
  value       = var.region
  description = "Region the state bucket lives in."
}

# The point of this output is that nobody has to reconstruct the backend
# block by hand from the other two. Paste it under `remote_state:` in
# infrastructure/configs/<env>/config.yaml.
output "remote_state_yaml" {
  description = "The remote_state block to paste into configs/<env>/config.yaml."
  value       = <<-EOT
    remote_state:
      backend: s3
      bucket: ${aws_s3_bucket.state.id}
      region: ${var.region}
      encrypt: true
      use_lockfile: true
  EOT
}

# The two values to set on the GitHub environments. Neither is secret: a
# role ARN is an identifier and a region is a place name. Both are useless
# without a token GitHub will only mint for the repository named in the
# roles' trust conditions — which is why these are variables, not secrets.
output "github_variables" {
  description = "GitHub environment variables, keyed by environment name."
  value = var.github_repository == "" ? {} : {
    (var.plan_environment) = {
      AWS_ROLE_ARN = aws_iam_role.plan[0].arn
      AWS_REGION   = var.environment_region != "" ? var.environment_region : var.region
    }
    (replace(var.plan_environment, "-plan", "")) = {
      AWS_ROLE_ARN = aws_iam_role.apply[0].arn
      AWS_REGION   = var.environment_region != "" ? var.environment_region : var.region
    }
  }
}
