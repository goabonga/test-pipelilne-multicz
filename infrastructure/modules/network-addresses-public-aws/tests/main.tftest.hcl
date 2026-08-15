# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every AWS call.
#
# The interesting assertions here are about the arithmetic AWS forces: a
# NAT gateway takes exactly one address, so the pool is the zone count and
# not the number in the environment config.

mock_provider "aws" {}

variables {
  name        = "shomer-test-nat"
  environment = "test"
  region      = "eu-west-3"
  zones       = ["eu-west-3a"]
  ip_count    = 1
}

run "one_address_per_zone" {
  command = plan

  assert {
    condition     = length(aws_eip.nat) == 1
    error_message = "One zone, one NAT gateway, one address."
  }

  # Domain vpc rather than the classic default. The classic form still
  # allocates and still attaches, and then behaves differently in ways that
  # surface much later.
  assert {
    condition     = aws_eip.nat["eu-west-3a"].domain == "vpc"
    error_message = "An EIP for a VPC NAT gateway must be a VPC address."
  }
}

run "the_pool_grows_with_zones" {
  command = plan

  variables {
    zones    = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
    ip_count = 3
  }

  # THE difference from GCP. There, the pool grows by adding addresses to
  # one NAT; here a NAT gateway has exactly one slot, so the pool grows by
  # adding zones.
  assert {
    condition     = length(aws_eip.nat) == 3
    error_message = "Each zone gets its own NAT gateway and therefore its own address."
  }

  # Keyed by zone: a NAT gateway must take the address in its own zone, and
  # a list would leave the pairing to index arithmetic in another module.
  assert {
    condition     = alltrue([for z in var.zones : contains(keys(output.allocation_ids), z)])
    error_message = "The NAT unit needs the address for its own zone, by name rather than by position."
  }

  assert {
    condition     = output.ip_count == 3
    error_message = "The reported pool size must be what exists, not what was asked for."
  }
}

run "asking_for_more_addresses_than_zones_is_refused" {
  command = plan

  variables {
    zones    = ["eu-west-3a"]
    ip_count = 4
  }

  # The failure that matters. Asking for four and silently receiving one is
  # discovered under load, months later, as intermittent connection
  # failures toward a single busy destination.
  expect_failures = [aws_eip.nat]
}

run "duplicate_zones_are_refused" {
  command = plan

  variables {
    zones = ["eu-west-3a", "eu-west-3a"]
  }

  expect_failures = [var.zones]
}
