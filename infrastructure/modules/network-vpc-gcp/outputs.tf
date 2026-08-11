# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "id" {
  value       = google_compute_network.this.id
  description = "Network id, consumed by subnets, firewall and routes."
}

output "name" {
  value       = google_compute_network.this.name
  description = "Network name."
}

output "self_link" {
  value       = google_compute_network.this.self_link
  description = "Network self link, required by resources that take a URL rather than a name."
}
