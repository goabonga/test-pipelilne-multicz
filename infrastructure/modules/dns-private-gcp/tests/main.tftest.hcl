# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

mock_provider "google" {}

variables {
  name        = "shomer-test-internal"
  environment = "test"
  region      = "europe-west1"
  project     = "shomer-test"
  domain      = "internal.shomer.test"
  networks    = ["projects/shomer-test/global/networks/shomer-test"]
}

run "the_zone_is_private_and_bound_to_a_network" {
  command = plan

  assert {
    condition     = google_dns_managed_zone.this.visibility == "private"
    error_message = "A public internal zone publishes the shape of the network to everyone."
  }

  # THE assertion. A private zone with no network resolves for nobody and
  # creates cleanly while doing so — the failure shows up as every internal
  # name being NXDOMAIN, which reads as a records problem.
  assert {
    condition     = length(google_dns_managed_zone.this.private_visibility_config[0].networks) == 1
    error_message = "A private zone with no network attached resolves for nobody."
  }
}

run "a_zone_bound_to_nothing_is_refused" {
  command = plan

  variables {
    networks = []
  }

  expect_failures = [var.networks]
}

run "a_trailing_dot_is_refused" {
  command = plan

  variables {
    domain = "internal.shomer.test."
  }

  # The module adds the dot where the API needs one. Accepting both forms
  # would produce a zone for "internal.shomer.test.." that creates fine.
  expect_failures = [var.domain]
}
