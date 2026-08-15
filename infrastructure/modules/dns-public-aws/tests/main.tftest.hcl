# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

mock_provider "aws" {}

variables {
  name        = "shomer-test-public"
  environment = "test"
  region      = "eu-west-3"
  domain      = "shomer.test"
}

run "an_unsigned_zone_says_so" {
  command = plan

  # DNSSEC needs a KMS key in us-east-1 — Route 53 signs only from there —
  # which the apply identity cannot create. The gap is real, so it is
  # reported rather than hidden.
  assert {
    condition     = output.signed == false
    error_message = "A plan should say whether the zone is signed."
  }

  assert {
    condition     = length(aws_route53_key_signing_key.this) == 0
    error_message = "With no key there is nothing to sign with, and a half-configured signing key leaves the zone in a broken state rather than an unsigned one."
  }
}

run "a_key_signs_the_zone" {
  command = plan

  variables {
    dnssec_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abcd"
  }

  assert {
    condition     = output.signed == true
    error_message = "Given a key, the zone must be signed."
  }

  assert {
    condition     = length(aws_route53_hosted_zone_dnssec.this) == 1
    error_message = "A signing key without enabling DNSSEC on the zone signs nothing."
  }
}

run "a_public_record_pointing_inside_is_refused" {
  command = plan

  variables {
    records = {
      api = { type = "A", values = ["10.10.17.5"] }
    }
  }

  expect_failures = [var.records]
}
