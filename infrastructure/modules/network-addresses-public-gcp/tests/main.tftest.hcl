# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every Google API call.
#
# These addresses are what external services allow-list, so the properties
# worth guarding are about them surviving their consumers and about the
# count meaning what the config says.

mock_provider "google" {}

variables {
  name        = "shomer-test-nat"
  environment = "test"
  region      = "europe-west1"
  project     = "shomer-test"
  ip_count    = 1
}

run "one_address_by_default_and_it_is_external" {
  command = plan

  assert {
    condition     = length(google_compute_address.nat) == 1
    error_message = "The config asks for a number of addresses; the module must reserve that many."
  }

  assert {
    condition     = google_compute_address.nat[0].address_type == "EXTERNAL"
    error_message = "An internal address here would leave the NAT with nothing to be seen from."
  }

  # Standard tier carries egress over the public internet from the region
  # it leaves, changing both the path and, for some destinations, the
  # address geography an allow-list was written against.
  assert {
    condition     = google_compute_address.nat[0].network_tier == "PREMIUM"
    error_message = "Premium is the default for a reason; choosing standard should be deliberate."
  }
}

run "the_pool_grows_by_the_number_asked_for" {
  command = plan

  variables {
    ip_count = 4
  }

  # Growing is the safe direction: new addresses join the pool and nothing
  # that was allow-listed changes.
  assert {
    condition     = length(google_compute_address.nat) == 4
    error_message = "Extending the pool must be a matter of the count and nothing else."
  }

  # Distinct names, or the second apply fails on a collision after the
  # first has already been created.
  assert {
    condition     = length(distinct(google_compute_address.nat[*].name)) == 4
    error_message = "Each address needs its own name."
  }

  assert {
    condition     = output.ip_count == 4
    error_message = "The NAT unit reads this to know how many addresses to attach; a mismatch leaves one billed and unused."
  }
}

run "zero_addresses_is_refused" {
  command = plan

  variables {
    ip_count = 0
  }

  # Cloud NAT with no reserved address falls back to allocating its own,
  # which works — and produces an egress address that changes whenever the
  # NAT is recreated, silently breaking every allow-list.
  expect_failures = [var.ip_count]
}

run "an_implausible_pool_is_refused" {
  command = plan

  variables {
    ip_count = 500
  }

  expect_failures = [var.ip_count]
}
