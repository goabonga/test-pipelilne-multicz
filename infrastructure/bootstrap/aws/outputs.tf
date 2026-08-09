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
