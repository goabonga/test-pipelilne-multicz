# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "ilb_forwarding_rule" {
  value       = google_compute_forwarding_rule.proxy.id
  description = <<-EOT
    What services/network/routes points the workload's default route at.

    Until this exists that route does not, and the workload has no way off
    the network at all — which is the intended resting state rather than an
    outage.
  EOT
}

output "ilb_address" {
  value       = google_compute_forwarding_rule.proxy.ip_address
  description = "The address workloads send their traffic to."
}

output "service_account_email" {
  value       = local.sa_email
  description = "The fleet's identity. Holds no project roles, and should keep holding none."
}

output "size" {
  value       = google_compute_region_instance_group_manager.proxy.target_size
  description = "How many proxies are running. One is a single point of failure for the whole estate's egress; ha makes it more."
}

output "allowed_domains" {
  value       = var.allowed_domains
  description = "The destinations this environment may reach. Exported so the policy is readable from a plan rather than only from a rendered config on a disk."
}
