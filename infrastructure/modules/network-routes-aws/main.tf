# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Every path off this network, in one file.
#
# The same intent as the GCP module, reached differently. GCP selects
# routes by instance tag across one network-wide table; AWS gives each
# subnet a route table, so the separation is which table a subnet is
# associated with. That makes it easier to read and easier to get wrong in
# one specific way: a subnet with no explicit association silently falls
# back to the VPC's main route table, so an association that is forgotten
# is not an error, it is a different set of routes.
#
# Every subnet here is associated explicitly, and the main route table is
# emptied so that a subnet which slips through has no routes rather than
# inherited ones.

locals {
  by_purpose = {
    for purpose in distinct([for k, v in var.subnets : v.purpose]) :
    purpose => [for k, v in var.subnets : k if v.purpose == purpose]
  }

  public_subnets   = try(local.by_purpose["public-lb"], [])
  proxy_subnets    = try(local.by_purpose["egress"], [])
  workload_subnets = try(local.by_purpose["workload"], [])
}

# THE ONLY DOOR. An internet gateway is inert without a route pointing at
# it, so it lives here rather than in the VPC module: one file answers
# "how does traffic leave?", and the gateway and the routes that use it
# cannot drift into different reviews.
resource "aws_internet_gateway" "this" {
  vpc_id = var.vpc_id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

# ── public: the load balancer and the NAT gateways ──────────────────────

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id
  tags   = merge(var.tags, { Name = "${var.name}-public", Purpose = "public-lb" })
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = toset(local.public_subnets)

  subnet_id      = var.subnets[each.value].id
  route_table_id = aws_route_table.public.id
}

# ── proxy: out through the NAT, never through the gateway ───────────────
#
# One table per zone, because a NAT gateway is zonal: a shared table would
# send one zone's traffic across a zone boundary to reach the other's NAT,
# which costs money on both sides and fails as a unit when that zone does.

resource "aws_route_table" "proxy" {
  for_each = toset(local.proxy_subnets)

  vpc_id = var.vpc_id
  tags   = merge(var.tags, { Name = "${var.name}-proxy-${each.value}", Purpose = "egress" })
}

# Absent until services/network/nat exists, exactly as the GCP module's
# workload route is absent until the proxy does. A gateway_id here "for
# now" would give the proxies unmediated egress and work perfectly, which
# is why it would survive review.
resource "aws_route" "proxy_default" {
  for_each = {
    for k in local.proxy_subnets : k => var.nat_gateway_ids[var.subnets[k].zone]
    if try(var.nat_gateway_ids[var.subnets[k].zone], null) != null
  }

  route_table_id         = aws_route_table.proxy[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = each.value
}

resource "aws_route_table_association" "proxy" {
  for_each = toset(local.proxy_subnets)

  subnet_id      = var.subnets[each.value].id
  route_table_id = aws_route_table.proxy[each.value].id
}

# ── workload: local only ────────────────────────────────────────────────
#
# A table with no default route. Not an oversight and not a placeholder:
# the workload subnets reach the rest of the VPC and, through the endpoints
# the firewall unit attaches, the AWS APIs. Anything else goes to the proxy
# because the proxy is the only thing they can reach that has a way out.
#
# This is the AWS shape of "the workload has no route out". There is no
# resource here to point at, which is the difficulty with asserting it —
# the test asserts that no route exists in this table at all.

resource "aws_route_table" "workload" {
  for_each = toset(local.workload_subnets)

  vpc_id = var.vpc_id
  tags = merge(var.tags, {
    Name    = "${var.name}-workload-${each.value}"
    Purpose = "workload"
    Egress  = "proxy-only"
  })
}

resource "aws_route_table_association" "workload" {
  for_each = toset(local.workload_subnets)

  subnet_id      = var.subnets[each.value].id
  route_table_id = aws_route_table.workload[each.value].id
}

# THE MAIN ROUTE TABLE IS EMPTIED.
#
# Every subnet above is associated explicitly, so nothing should ever use
# this. That is exactly why it matters: a subnet added later without an
# association does not fail, it silently inherits whatever this table
# holds. Emptied, the worst that inheritance can produce is a subnet with
# no routes — a loud failure in the new thing rather than a quiet path out.
resource "aws_default_route_table" "this" {
  default_route_table_id = var.default_route_table_id

  tags = merge(var.tags, { Name = "${var.name}-main-DO-NOT-USE" })
}
