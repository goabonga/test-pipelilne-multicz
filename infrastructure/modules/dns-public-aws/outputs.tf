# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "zone_id" {
  value       = aws_route53_zone.this.zone_id
  description = "Zone id."
}

output "domain" {
  value       = var.domain
  description = "The domain this zone serves."
}

output "name_servers" {
  value       = aws_route53_zone.this.name_servers
  description = <<-EOT
    The servers to delegate to at the registrar.

    Until that delegation exists the zone is authoritative for nothing, and
    every record in it is correct and unreachable — which looks exactly
    like a propagation delay for as long as anyone is willing to wait.
  EOT
}

output "signed" {
  value       = var.dnssec_key_arn != null
  description = "Whether the zone is signed. Readable from a plan rather than inferred from the presence of a key ARN."
}

output "visibility" {
  value       = "public"
  description = "Constant, and stated so a plan says it out loud. Only production should have one at all."
}
