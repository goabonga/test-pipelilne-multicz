# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every Google API call.

mock_provider "google" {}

variables {
  name        = "shomer-test-proxy-ilb"
  environment = "test"
  region      = "europe-west1"
  project     = "shomer-test"
  subnetwork  = "projects/shomer-test/regions/europe-west1/subnetworks/shomer-test-proxy"
  subnet_cidr = "10.10.16.0/24"
}

run "the_address_is_internal_and_inside_the_proxy_subnet" {
  command = plan

  # An external address here would be a way to the internet that bypasses
  # the NAT, reserved by the unit whose job is the opposite.
  assert {
    condition     = google_compute_address.proxy_ilb.address_type == "INTERNAL"
    error_message = "This address is a load balancer VIP inside the network, not a public one."
  }

  # Derived rather than written out, which is what makes landing outside
  # the subnet impossible instead of merely detectable.
  assert {
    condition     = google_compute_address.proxy_ilb.address == "10.10.16.10"
    error_message = "The address must be the requested index within the proxy subnet."
  }
}

run "a_reserved_index_is_refused" {
  command = plan

  variables {
    address_index = 1
  }

  # The gateway. Asking for it fails at apply with a message about the
  # address being in use, which reads as a collision with something
  # somebody else created.
  expect_failures = [var.address_index]
}

run "moving_the_index_moves_the_address" {
  command = plan

  variables {
    address_index = 20
  }

  # Both services/network/routes and services/vms/proxy read the same value
  # from the same config key, so this is the one number that has to agree
  # in two places — and neither reads it from the other.
  assert {
    condition     = google_compute_address.proxy_ilb.address == "10.10.16.20"
    error_message = "The index must decide the address, or the two consumers cannot agree without depending on each other."
  }
}
