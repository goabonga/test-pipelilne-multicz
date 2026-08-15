# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "allocation_ids" {
  value       = { for z, e in aws_eip.nat : z => e.allocation_id }
  description = "Keyed by zone, because a NAT gateway is zonal and must take the address in its own zone."
}

output "addresses" {
  value       = [for e in aws_eip.nat : e.public_ip]
  description = <<-EOT
    The addresses themselves. THIS IS THE LIST TO HAND TO ANYONE WHO ASKS
    what to allow-list.
  EOT
}

output "ip_count" {
  value       = length(var.zones)
  description = <<-EOT
    How many addresses exist — the zone count, not the requested ip_count.

    Reported separately because on AWS those two numbers can legitimately
    differ from what a reader of the environment config expects, and the
    pool size is the one that decides how many ports the estate has toward
    a single destination.
  EOT
}
