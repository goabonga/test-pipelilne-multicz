# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Address translation for the egress proxies, and for nothing else.
#
# WHERE THE GATEWAY SITS IS THE WHOLE DESIGN, and it is the opposite of
# what the name suggests. A NAT gateway must live in a subnet that has a
# route to the internet gateway — the PUBLIC subnet — and it serves the
# private subnets that route to it. Placing it in the proxy subnet, which
# reads as the natural home, produces a gateway with no way out and a
# failure that looks like a routing problem.
#
# The counterpart of the GCP module's subnet list is here a matter of who
# routes to this gateway, decided in services/network/routes: the proxy
# tables point at it and the workload tables have no default route at all.
# Nothing in THIS module can grant the workload egress, which is a property
# of the split worth stating rather than assuming.

resource "aws_nat_gateway" "this" {
  for_each = var.public_subnet_ids

  subnet_id     = each.value
  allocation_id = var.allocation_ids[each.key]

  # "public" rather than "private": a private connectivity type gives a
  # gateway that translates between VPCs and cannot reach the internet at
  # all, which is a different product wearing the same name.
  connectivity_type = "public"

  tags = merge(var.tags, {
    Name = "${var.name}-${each.key}"
    Zone = each.key
  })

  lifecycle {
    precondition {
      # A gateway in a zone whose address belongs to another zone does not
      # fail at creation; it fails later, as traffic that cannot leave.
      condition     = contains(keys(var.allocation_ids), each.key)
      error_message = "No egress address reserved for this zone. services/network/addresses/public allocates one per zone, so a zone added there and not here — or the reverse — leaves a gateway with nothing to be seen from."
    }
  }
}
