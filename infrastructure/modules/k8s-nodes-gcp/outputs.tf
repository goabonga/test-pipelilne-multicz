# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "name" {
  value       = google_container_node_pool.this.name
  description = "Pool name."
}

output "service_account_email" {
  value       = local.sa_email
  description = "The node identity. Holds logging, monitoring and image pull, and should keep holding no more."
}

output "zones" {
  value       = local.zones
  description = "Where the pool actually runs. One zone without ha, which makes a zone failure a cluster failure."
}

output "workload_tag" {
  value       = var.workload_tag
  description = "The tag that routes these nodes' egress through the proxy. Must match what services/network/routes and services/network/firewall expect."
}
