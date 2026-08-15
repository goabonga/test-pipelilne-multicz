# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The addresses the whole estate is seen from.
#
# Every outbound connection leaves through the proxy and then through the
# NAT, so these are the addresses an external service allow-lists. That
# makes them the most consequential thing here to change: releasing one
# silently breaks every partner who wrote it down, and no part of the
# infrastructure notices.
#
# They are reserved in their own unit rather than allocated automatically
# by Cloud NAT for exactly that reason. An automatic address is released
# and reallocated when the NAT is recreated; a reserved one outlives its
# consumer, so replacing the NAT does not change who the world sees.
#
# There is no prevent_destroy here. It cannot be driven by a variable, it
# would block a deliberate reduction as firmly as an accidental one, and it
# would break `terraform test`, whose teardown destroys everything. The
# control that actually applies is the plan attached to the deploy PR: an
# address being released appears there as a destroy, in front of a
# reviewer, before it happens.

resource "google_compute_address" "nat" {
  count = var.ip_count

  name        = "${var.name}-${count.index + 1}"
  project     = var.project
  region      = var.region
  description = "Egress address ${count.index + 1}. Allow-listed by external services; releasing it is a breaking change nothing else will report."

  address_type = "EXTERNAL"

  # PREMIUM, and not by accident. Standard tier routes egress over the
  # public internet from the region it leaves, which changes the path
  # traffic takes and, for some destinations, the address geography an
  # allow-list was written against. It is also the only tier that supports
  # a global load balancer later.
  network_tier = var.network_tier
}
