# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every AWS call.
#
# Like its GCP counterpart, most of this asserts that something does NOT
# exist. "The workload has no way out" has no resource to point at, so the
# only honest form the check can take is counting what was created.

mock_provider "aws" {}

variables {
  name                   = "shomer-test"
  environment            = "test"
  region                 = "eu-west-3"
  vpc_id                 = "vpc-0123456789abcdef0"
  default_route_table_id = "rtb-0123456789abcdef0"

  subnets = {
    "workload-eu-west-3a" = { id = "subnet-aaa", purpose = "workload", zone = "eu-west-3a" }
    "proxy-eu-west-3a"    = { id = "subnet-bbb", purpose = "egress", zone = "eu-west-3a" }
    "lb-eu-west-3a"       = { id = "subnet-ccc", purpose = "public-lb", zone = "eu-west-3a" }
  }
}

run "the_workload_table_has_no_routes_at_all" {
  command = plan

  # THE assertion in this module. There is no resource representing "no
  # default route", so the check is that every default route created
  # belongs to a subnet whose purpose is allowed to have one.
  #
  # Written against the resource KEYS rather than route table ids: an id is
  # computed, so at plan it is unknown and the comparison cannot be
  # evaluated at all. The keys are the subnet names, which are known.
  assert {
    condition     = alltrue([for k in keys(aws_route.proxy_default) : var.subnets[k].purpose == "egress"])
    error_message = "A default route was created for a subnet that is not an egress subnet."
  }

  assert {
    condition     = alltrue([for k in keys(aws_route_table_association.workload) : var.subnets[k].purpose == "workload"])
    error_message = "A non-workload subnet was associated with a table that has no way out."
  }

  assert {
    condition     = length(aws_route_table.workload) == 1
    error_message = "Each workload subnet needs its own table, or it falls back to the main one."
  }
}

run "every_subnet_is_associated_explicitly" {
  command = plan

  # A subnet with no association does not fail — it silently uses the VPC's
  # main route table. A forgotten association is therefore not an error but
  # a different set of routes, which is the worst kind of mistake this
  # module can make.
  assert {
    condition     = length(aws_route_table_association.public) + length(aws_route_table_association.proxy) + length(aws_route_table_association.workload) == length(var.subnets)
    error_message = "Every subnet must be associated explicitly. An unassociated subnet quietly inherits the main table instead of failing."
  }
}

run "the_main_route_table_is_emptied" {
  command = apply

  # Nothing should ever use it, which is exactly why it is managed: a
  # subnet added later without an association inherits whatever it holds.
  # Emptied, the worst that inheritance produces is a subnet with no routes
  # — a loud failure in the new thing rather than a quiet path out.
  assert {
    condition     = length(aws_default_route_table.this.route) == 0
    error_message = "The main route table has a route. Anything that slips through association would inherit it."
  }

  assert {
    condition     = can(regex("DO-NOT-USE", aws_default_route_table.this.tags["Name"]))
    error_message = "The main table should be named to warn off anyone about to associate something with it."
  }
}

run "the_proxies_have_no_way_out_until_the_nat_exists" {
  command = plan

  # The resting state. A gateway_id here "for now" would give the proxy
  # fleet unmediated egress and work perfectly, which is why it would
  # survive review.
  assert {
    condition     = length(aws_route.proxy_default) == 0
    error_message = "With no NAT to point at, the proxy subnets must have no default route."
  }

  assert {
    condition     = output.proxy_has_egress == false
    error_message = "A plan should say whether the proxies can reach the internet without a reader inferring it from an absent resource."
  }
}

run "the_proxy_route_appears_once_the_nat_does_and_goes_to_the_nat" {
  command = plan

  variables {
    nat_gateway_ids = { "eu-west-3a" = "nat-0123456789abcdef0" }
  }

  assert {
    condition     = length(aws_route.proxy_default) == 1
    error_message = "Given a NAT to point at, the proxy subnet must get its route."
  }

  # Through the NAT, never through the gateway. A gateway here would make
  # the NAT — and its fixed, extensible address pool — pointless.
  assert {
    condition     = aws_route.proxy_default["proxy-eu-west-3a"].nat_gateway_id == "nat-0123456789abcdef0"
    error_message = "The proxy's way out must be the NAT, whose addresses are the ones an external service allow-lists."
  }

  assert {
    condition     = aws_route.proxy_default["proxy-eu-west-3a"].gateway_id == null
    error_message = "A gateway on the proxy route bypasses the NAT and the fixed egress addresses with it."
  }
}

run "each_zone_gets_its_own_proxy_table" {
  command = plan

  variables {
    subnets = {
      "workload-eu-west-3a" = { id = "subnet-aaa", purpose = "workload", zone = "eu-west-3a" }
      "workload-eu-west-3b" = { id = "subnet-ddd", purpose = "workload", zone = "eu-west-3b" }
      "proxy-eu-west-3a"    = { id = "subnet-bbb", purpose = "egress", zone = "eu-west-3a" }
      "proxy-eu-west-3b"    = { id = "subnet-eee", purpose = "egress", zone = "eu-west-3b" }
      "lb-eu-west-3a"       = { id = "subnet-ccc", purpose = "public-lb", zone = "eu-west-3a" }
    }
    nat_gateway_ids = {
      "eu-west-3a" = "nat-000000000000000a"
      "eu-west-3b" = "nat-000000000000000b"
    }
  }

  # A NAT gateway is zonal. A shared table would send one zone's traffic
  # across a zone boundary to reach the other's NAT — billed on both sides,
  # and failing as a unit when that zone does.
  assert {
    condition     = length(aws_route_table.proxy) == 2
    error_message = "Each proxy subnet needs its own table, or one zone's egress depends on another zone staying up."
  }

  assert {
    condition     = aws_route.proxy_default["proxy-eu-west-3a"].nat_gateway_id == "nat-000000000000000a" && aws_route.proxy_default["proxy-eu-west-3b"].nat_gateway_id == "nat-000000000000000b"
    error_message = "Each zone must route to the NAT in its own zone."
  }
}

run "a_partially_built_nat_routes_only_what_it_can" {
  command = plan

  variables {
    subnets = {
      "workload-eu-west-3a" = { id = "subnet-aaa", purpose = "workload", zone = "eu-west-3a" }
      "proxy-eu-west-3a"    = { id = "subnet-bbb", purpose = "egress", zone = "eu-west-3a" }
      "proxy-eu-west-3b"    = { id = "subnet-eee", purpose = "egress", zone = "eu-west-3b" }
    }
    nat_gateway_ids = { "eu-west-3a" = "nat-000000000000000a" }
  }

  # A zone whose NAT is missing gets no default route rather than borrowing
  # another zone's. Borrowing would work, cost cross-zone traffic on every
  # packet, and never be noticed.
  assert {
    condition     = length(aws_route.proxy_default) == 1
    error_message = "A zone with no NAT must get no route, not another zone's."
  }
}

run "an_unknown_purpose_is_refused" {
  command = plan

  variables {
    subnets = {
      "odd-eu-west-3a" = { id = "subnet-zzz", purpose = "database", zone = "eu-west-3a" }
    }
  }

  # It would match no branch, get no association, and fall back to the main
  # table — which reads as "isolated by design" and is not.
  expect_failures = [var.subnets]
}
