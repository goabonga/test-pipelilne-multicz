# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "bucket" {
  value       = google_storage_bucket.state.name
  description = "Name of the state bucket."
}

output "location" {
  value       = google_storage_bucket.state.location
  description = "Location the state bucket lives in."
}

# The point of this output is that nobody has to reconstruct the backend
# block by hand. Paste it under `remote_state:` in
# infrastructure/configs/<env>/config.yaml.
output "remote_state_yaml" {
  description = "The remote_state block to paste into configs/<env>/config.yaml."
  value       = <<-EOT
    remote_state:
      backend: gcs
      bucket: ${google_storage_bucket.state.name}
      project: ${var.project}
  EOT
}

# The two values to set on the GitHub environments. Neither is secret: the
# provider name is a resource path and the service account is an email
# address. Both are useless without a token GitHub will only mint for the
# repository named in the provider's attribute condition — which is why
# these are variables rather than secrets.
output "github_variables" {
  description = "GitHub environment variables, keyed by environment name."
  value = var.github_repository == "" ? {} : {
    (var.plan_environment) = {
      GCP_WORKLOAD_IDENTITY_PROVIDER = google_iam_workload_identity_pool_provider.github[0].name
      GCP_SERVICE_ACCOUNT            = local.plan_email
    }
    (replace(var.plan_environment, "-plan", "")) = {
      GCP_WORKLOAD_IDENTITY_PROVIDER = google_iam_workload_identity_pool_provider.github[0].name
      GCP_SERVICE_ACCOUNT            = local.apply_email
    }
  }
}
