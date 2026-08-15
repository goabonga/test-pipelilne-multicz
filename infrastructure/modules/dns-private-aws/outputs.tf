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

output "visibility" {
  value       = "private"
  description = "Constant, and stated so a plan answers 'is this zone reachable from outside?' without a reader inferring it from the presence of a vpc block."
}
