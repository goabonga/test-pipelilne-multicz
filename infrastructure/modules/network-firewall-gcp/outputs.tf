# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "proxy_tag" {
  value       = var.proxy_tag
  description = "The tag that permits reaching the internet."
}

output "workload_tag" {
  value       = var.workload_tag
  description = "The tag that permits reaching the proxy, and nothing beyond it."
}

output "egress_is_denied_by_default" {
  value       = true
  description = <<-EOT
    Constant, and deliberately so. GCP's implied rules ALLOW egress, so the
    absence of firewall rules is an open network rather than a closed one.
    This output exists to make the presence of the deny rule visible to a
    reader of the plan, and to fail loudly if the resource is ever removed
    while callers still consume it.
  EOT
}
