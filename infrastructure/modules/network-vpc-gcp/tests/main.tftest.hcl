# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every Google API call, so this needs
# no credentials and no network.
#
# The assertions are about the properties the design depends on, not about
# terraform's ability to create a network. Each has a failure mode that
# stays quiet until something leaks.

mock_provider "google" {}

variables {
  name        = "shomer-test"
  environment = "test"
  region      = "europe-west1"
  project     = "shomer-test"
}

run "custom_mode_only" {
  command = plan

  assert {
    condition     = google_compute_network.this.auto_create_subnetworks == false
    error_message = "Auto mode creates a subnet per region behind the subnets unit's back, in 10.128.0.0/9 — which collides with the environment CIDR plan."
  }
}

run "the_default_internet_route_is_removed" {
  command = plan

  assert {
    condition     = google_compute_network.this.delete_default_routes_on_create
    error_message = "A fresh VPC ships a 0.0.0.0/0 route to the internet gateway. Leaving it lets workloads egress without the proxy, which is the one thing this topology exists to prevent."
  }
}

run "keeping_the_default_route_needs_saying_so" {
  command = plan

  variables {
    delete_default_routes = false
  }

  # The precondition must reject this: turning the guard off is one flag,
  # and a single flag should not be able to open the whole network.
  expect_failures = [google_compute_network.this]
}

run "the_escape_hatch_works_when_acknowledged" {
  command = plan

  variables {
    delete_default_routes        = false
    allow_default_internet_route = true
  }

  assert {
    condition     = google_compute_network.this.delete_default_routes_on_create == false
    error_message = "With both flags set the default route is kept, deliberately."
  }
}

run "routing_mode_is_validated" {
  command = plan

  variables {
    routing_mode = "GLOBAL"
  }

  assert {
    condition     = google_compute_network.this.routing_mode == "GLOBAL"
    error_message = "routing_mode must reach the resource."
  }
}
