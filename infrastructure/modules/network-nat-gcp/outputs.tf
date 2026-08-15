# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "router_name" {
  value       = google_compute_router.this.name
  description = "The router carrying the NAT configuration."
}

output "nat_name" {
  value       = google_compute_router_nat.this.name
  description = "The NAT itself."
}

output "translated_subnetworks" {
  value       = var.subnetworks
  description = <<-EOT
    Which subnets have their addresses translated. Exported so a reader can
    confirm from the plan that the workload subnet is not among them, which
    is the property the whole egress design rests on.
  EOT
}
