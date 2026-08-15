# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# No provider at all: this module creates nothing. Its job is to decide an
# address so two units can agree without depending on each other, and that
# is what these check.

variables {
  name        = "shomer-test-proxy-ilb"
  environment = "test"
  region      = "eu-west-3"

  subnet_cidrs = {
    "eu-west-3a" = "10.10.16.0/26"
    "eu-west-3b" = "10.10.16.64/26"
  }
}

run "one_address_per_zone_from_that_zones_range" {
  command = plan

  # A load balancer takes one address per subnet it sits in, and each has
  # to come from that subnet — not from the first one repeated.
  assert {
    condition     = output.addresses["eu-west-3a"] == "10.10.16.10" && output.addresses["eu-west-3b"] == "10.10.16.74"
    error_message = "Each zone's address must come from that zone's own range."
  }

  assert {
    condition     = length(distinct(values(output.addresses))) == 2
    error_message = "Two zones must get two different addresses."
  }
}

run "the_module_says_it_reserves_nothing" {
  command = plan

  # The unit's name implies a reservation and there is none. Saying so in
  # an output means a reader of the plan is not left to infer it from an
  # absence of resources.
  assert {
    condition     = output.reserved == false
    error_message = "AWS has no reservation for a private address; the module should not imply one."
  }
}

run "a_reserved_index_is_refused" {
  command = plan

  variables {
    address_index = 2
  }

  # The VPC router. Claiming it fails at attach time with a message about
  # the address being unavailable, which reads as a collision with
  # something somebody else created.
  expect_failures = [var.address_index]
}

run "no_subnets_is_refused" {
  command = plan

  variables {
    subnet_cidrs = {}
  }

  expect_failures = [terraform_data.addresses]
}
