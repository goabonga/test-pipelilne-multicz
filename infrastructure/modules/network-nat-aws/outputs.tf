# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "nat_gateway_ids" {
  value       = { for z, n in aws_nat_gateway.this : z => n.id }
  description = <<-EOT
    Keyed by zone. services/network/routes consumes this to give each
    proxy subnet a default route to the gateway in its OWN zone — a shared
    one would cross a zone boundary on every packet and fail as a unit when
    that zone did.
  EOT
}

output "addresses" {
  value       = [for n in aws_nat_gateway.this : n.public_ip]
  description = "The addresses traffic is seen from. Should match what services/network/addresses/public reserved; if it does not, a gateway allocated its own."
}
