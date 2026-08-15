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
  description = <<-EOT
    The servers to delegate to at the registrar.

    Until that delegation exists the zone is authoritative for nothing, and
    every record in it is correct and unreachable — which looks exactly
    like a propagation delay for as long as anyone is willing to wait.
  EOT
}

output "visibility" {
  value       = "public"
  description = "Constant, and stated so a plan answers 'is this zone reachable from outside?' out loud. Only production should have one at all."
}
