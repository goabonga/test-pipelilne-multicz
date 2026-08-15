# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "addresses" {
  value       = local.addresses
  description = <<-EOT
    The proxy load balancer's private address per zone.

    Nothing is reserved — AWS has no such reservation — so these are
    claimed by services/vms/proxy through subnet_mapping. Deciding them
    here is what lets the proxy's clients be configured before the load
    balancer exists.
  EOT
}

output "reserved" {
  value       = false
  description = <<-EOT
    Constant, and stated because the module's name implies otherwise. AWS
    has no reservation for a private address: these are decided here and
    claimed at attach time, so nothing holds them in the meantime and a
    conflicting claim fails then rather than now.
  EOT
}
