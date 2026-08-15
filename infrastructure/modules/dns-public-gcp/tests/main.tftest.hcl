# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The one zone the internet reads. DNS is cached, so a record published by
# accident is out there for its TTL whatever is done next — which is why
# these assertions are about refusing things rather than creating them.

mock_provider "google" {}

variables {
  name        = "shomer-test-public"
  environment = "test"
  region      = "europe-west1"
  project     = "shomer-test"
  domain      = "shomer.test"
}

run "the_zone_is_signed" {
  command = plan

  # This zone serves the one public entry point to an otherwise private
  # estate, which makes it worth being unable to forge.
  assert {
    condition     = google_dns_managed_zone.this.dnssec_config[0].state == "on"
    error_message = "An unsigned public zone can be forged, and it is the only name anyone outside resolves."
  }

  assert {
    condition     = google_dns_managed_zone.this.visibility == "public"
    error_message = "This module is the public zone; a private one belongs in dns/private."
  }
}

run "a_public_record_pointing_inside_is_refused" {
  command = plan

  variables {
    records = {
      api = { type = "A", values = ["10.10.17.5"] }
    }
  }

  # It would resolve usefully for nobody outside the network and tell the
  # world the shape of one that is meant to be private. Both halves are
  # bad and neither produces an error at creation.
  expect_failures = [var.records]
}

run "a_public_record_pointing_outside_is_allowed" {
  command = plan

  variables {
    records = {
      api = { type = "A", values = ["203.0.113.10"] }
    }
  }

  assert {
    condition     = length(google_dns_record_set.this) == 1
    error_message = "The load balancer's own address is exactly what belongs here."
  }
}

run "an_unrecognised_record_type_is_refused" {
  command = plan

  variables {
    records = {
      odd = { type = "SPF", values = ["v=spf1 -all"] }
    }
  }

  # SPF as a record type was deprecated in favour of TXT. It creates, and
  # nothing reads it.
  expect_failures = [var.records]
}
