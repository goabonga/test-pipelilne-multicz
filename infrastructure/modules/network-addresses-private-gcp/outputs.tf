# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "address" {
  value       = google_compute_address.proxy_ilb.address
  description = <<-EOT
    The proxy's internal address.

    Consumed by services/network/routes as the workload's next hop and by
    services/vms/proxy as its forwarding rule's address — neither depending
    on the other, which is the whole reason this unit exists.
  EOT
}

output "self_link" {
  value       = google_compute_address.proxy_ilb.self_link
  description = "The reservation itself."
}
