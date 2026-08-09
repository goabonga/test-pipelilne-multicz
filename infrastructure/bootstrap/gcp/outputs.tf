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
