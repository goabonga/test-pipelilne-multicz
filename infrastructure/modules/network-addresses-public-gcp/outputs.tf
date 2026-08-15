# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "self_links" {
  value       = google_compute_address.nat[*].self_link
  description = "What Cloud NAT attaches to."
}

output "addresses" {
  value       = google_compute_address.nat[*].address
  description = <<-EOT
    The addresses themselves. THIS IS THE LIST TO HAND TO ANYONE WHO ASKS
    what to allow-list, and the list to check before reducing ip_count.
  EOT
}

output "ip_count" {
  value       = var.ip_count
  description = "How many addresses are reserved. Consumed by the NAT unit, which must attach every one of them or the estate pays for an address it never uses."
}
