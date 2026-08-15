# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every AWS call.
#
# The property that carries this module is placement, and it is
# counter-intuitive: the gateway belongs in the PUBLIC subnet, not the
# proxy one it serves.

mock_provider "aws" {}

variables {
  name        = "shomer-test-nat"
  environment = "test"
  region      = "eu-west-3"

  public_subnet_ids = { "eu-west-3a" = "subnet-public-a" }
  allocation_ids    = { "eu-west-3a" = "eipalloc-aaa" }
}

run "the_gateway_sits_in_the_public_subnet" {
  command = plan

  # The intuitive answer — put it in the subnet it serves — gives a gateway
  # with no route to the internet gateway, and the failure presents as a
  # routing problem in the workloads behind it rather than here.
  assert {
    condition     = aws_nat_gateway.this["eu-west-3a"].subnet_id == "subnet-public-a"
    error_message = "The NAT gateway must live in a subnet that has a route to the internet gateway."
  }

  # "private" connectivity is a different product wearing the same name: it
  # translates between VPCs and cannot reach the internet at all.
  assert {
    condition     = aws_nat_gateway.this["eu-west-3a"].connectivity_type == "public"
    error_message = "A private connectivity type cannot reach the internet, which is the one thing this gateway is for."
  }
}

run "each_zone_uses_its_own_reserved_address" {
  command = plan

  variables {
    public_subnet_ids = { "eu-west-3a" = "subnet-public-a", "eu-west-3b" = "subnet-public-b" }
    allocation_ids    = { "eu-west-3a" = "eipalloc-aaa", "eu-west-3b" = "eipalloc-bbb" }
  }

  assert {
    condition     = aws_nat_gateway.this["eu-west-3a"].allocation_id == "eipalloc-aaa" && aws_nat_gateway.this["eu-west-3b"].allocation_id == "eipalloc-bbb"
    error_message = "Each zone's gateway must take the address reserved for that zone."
  }

  # Keyed by zone for the routes unit, which gives each proxy subnet a
  # default route to the gateway in its OWN zone.
  assert {
    condition     = length(output.nat_gateway_ids) == 2
    error_message = "Every zone's gateway must be published, or a proxy subnet ends up routing across a zone boundary."
  }
}

run "a_zone_without_a_reserved_address_is_refused" {
  command = plan

  variables {
    public_subnet_ids = { "eu-west-3a" = "subnet-public-a", "eu-west-3b" = "subnet-public-b" }
    allocation_ids    = { "eu-west-3a" = "eipalloc-aaa" }
  }

  # A zone added to the subnets and not to the addresses, or the reverse.
  # Without this it fails later, as traffic that cannot leave one zone.
  expect_failures = [aws_nat_gateway.this]
}

run "no_gateway_at_all_is_refused" {
  command = plan

  variables {
    public_subnet_ids = {}
  }

  expect_failures = [var.public_subnet_ids]
}
