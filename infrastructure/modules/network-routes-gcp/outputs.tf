# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "proxy_tag" {
  value       = var.proxy_tag
  description = "The tag that grants direct internet access. The proxy unit must put it on its instances and nothing else may carry it."
}

output "workload_tag" {
  value       = var.workload_tag
  description = "The tag that routes egress through the proxy. The node pool unit puts it on its nodes."
}

output "workload_has_egress" {
  value       = length(google_compute_route.workload_egress) > 0
  description = <<-EOT
    Whether the workload nodes have a default route yet. False until the
    proxy exists — a fact worth being able to read from a plan rather than
    inferring from the absence of a resource.
  EOT
}
