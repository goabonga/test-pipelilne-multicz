# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The addresses the whole estate is seen from — the AWS side, where the
# arithmetic is not the same and the difference matters.
#
# A GCP Cloud NAT takes a LIST of addresses and spreads connections across
# them, so the pool grows by adding addresses. AN AWS NAT GATEWAY TAKES
# EXACTLY ONE, and there is no second slot: the pool grows by adding NAT
# gateways, and a NAT gateway is zonal, so it grows by adding zones.
#
# That is why this module allocates one address per zone rather than
# ip_count of them. Allocating more would produce addresses that are billed
# hourly, appear in the output as though they were part of the pool, and
# are attached to nothing — which is worse than not having them, because
# somebody would eventually allow-list one.
#
# The consequence for capacity is real and worth stating: each address
# gives roughly 64k ports toward a single destination, and on AWS the only
# way to raise that ceiling is another zone. Staging with one zone has one
# address and one such budget.

resource "aws_eip" "nat" {
  # checkov:skip=CKV2_AWS_19: These attach to NAT gateways in
  # services/network/nat, which depends on this unit — checkov cannot see
  # across the module boundary. The rule's premise is also narrower than the
  # problem it is named for: it looks for an attachment to an EC2 INSTANCE,
  # and an address on a NAT gateway is attached, just not to one.
  #
  # The concern behind it is real though, and is why this module allocates
  # one address per zone rather than ip_count of them: an unattached elastic
  # address is billed hourly and, worse, appears in the outputs as part of
  # the egress pool, so somebody eventually allow-lists an address nothing
  # ever leaves from.
  for_each = toset(var.zones)

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-${each.value}"
    Zone = each.value
    Note = "egress address — allow-listed externally"
  })

  lifecycle {
    precondition {
      # Fails loudly rather than silently ignoring the number in the
      # environment config. Asking for four addresses and receiving one is
      # the kind of thing that is discovered under load, months later.
      condition     = var.ip_count <= length(var.zones)
      error_message = "ip_count exceeds the number of zones. An AWS NAT gateway accepts exactly one address, so the egress pool is one per zone — raising it means adding a zone, not raising this number."
    }
  }
}
