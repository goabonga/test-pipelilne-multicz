# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "name" {
  value       = google_dns_managed_zone.this.name
  description = "Zone name."
}

output "domain" {
  value       = var.domain
  description = "The domain this zone serves."
}

output "name_servers" {
  value       = google_dns_managed_zone.this.name_servers
  description = "The zone's servers. Internal only — nothing outside the attached networks can reach them."
}

output "visibility" {
  value       = "private"
  description = "Constant, and stated so a plan answers 'is this zone reachable from outside?' without a reader inferring it from the absence of a public block."
}
