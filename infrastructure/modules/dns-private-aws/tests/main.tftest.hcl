# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

mock_provider "aws" {}

variables {
  name        = "shomer-test-internal"
  environment = "test"
  region      = "eu-west-3"
  domain      = "internal.shomer.test"
  vpc_ids     = ["vpc-0123456789abcdef0"]
}

run "the_zone_is_bound_to_a_vpc" {
  command = plan

  # A Route 53 private zone with no VPC resolves for nobody and creates
  # cleanly while doing so. The failure surfaces as every internal name
  # being NXDOMAIN, which reads as a records problem rather than a zone one.
  assert {
    condition     = length(aws_route53_zone.this.vpc) == 1
    error_message = "A private zone with no VPC attached resolves for nobody."
  }
}

run "a_zone_bound_to_nothing_is_refused" {
  command = plan

  variables {
    vpc_ids = []
  }

  expect_failures = [var.vpc_ids]
}
