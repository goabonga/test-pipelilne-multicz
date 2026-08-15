# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every Google API call.
#
# Two properties carry this module, and both are defaults that would work
# perfectly if accepted: which subnets are translated, and where the
# addresses come from.

mock_provider "google" {}

variables {
  name        = "shomer-test-nat"
  environment = "test"
  region      = "europe-west1"
  project     = "shomer-test"
  network_id  = "projects/shomer-test/global/networks/shomer-test"
  subnetworks = ["projects/shomer-test/regions/europe-west1/subnetworks/shomer-test-proxy"]
  nat_ips     = ["projects/shomer-test/regions/europe-west1/addresses/shomer-test-nat-1"]
}

run "only_the_listed_subnets_are_translated" {
  command = plan

  # THE assertion. Cloud NAT defaults to ALL_SUBNETWORKS_ALL_IP_RANGES,
  # which would give the workload subnet a path to the internet that does
  # not pass the proxy, needs no route, appears in no firewall rule, and
  # works — undoing routes and firewall at once from one unrelated line.
  assert {
    condition     = google_compute_router_nat.this.source_subnetwork_ip_ranges_to_nat == "LIST_OF_SUBNETWORKS"
    error_message = "ALL_SUBNETWORKS gives the workload subnet egress that bypasses the proxy entirely."
  }

  assert {
    condition     = length(google_compute_router_nat.this.subnetwork) == 1
    error_message = "Only the egress subnet should be translated."
  }

  # Nothing whose name says workload may appear in the list. Written as a
  # name check because the module cannot see purposes — this is the last
  # place the mistake can be caught before it becomes a working bypass.
  assert {
    condition = alltrue([
      for s in google_compute_router_nat.this.subnetwork : !can(regex("workload", s.name))
    ])
    error_message = "A workload subnet is being translated. That is a way to the internet that passes neither the proxy nor any rule."
  }
}

run "the_addresses_are_the_reserved_ones" {
  command = plan

  # AUTO_ONLY works perfectly and changes the egress address whenever the
  # NAT is recreated, breaking every external allow-list, while the
  # reserved addresses sit unused and billed.
  assert {
    condition     = google_compute_router_nat.this.nat_ip_allocate_option == "MANUAL_ONLY"
    error_message = "Automatic allocation makes the reserved addresses pointless and the egress address unstable."
  }

  assert {
    condition     = length(google_compute_router_nat.this.nat_ips) == 1
    error_message = "The reserved addresses must all be attached, or the estate pays for one it never leaves from."
  }
}

run "a_nat_with_no_addresses_is_refused" {
  command = plan

  variables {
    nat_ips = []
  }

  # MANUAL_ONLY with an empty list is accepted by the API and leaves the
  # proxies unable to reach anything.
  expect_failures = [google_compute_router_nat.this]
}

run "a_nat_that_translates_nothing_is_refused" {
  command = plan

  variables {
    subnetworks = []
  }

  expect_failures = [var.subnetworks]
}

run "errors_are_logged_and_translations_are_not" {
  command = plan

  # A dropped translation explains an outage. Logging every successful one
  # on a busy proxy fleet produces volume nobody reads and a bill somebody
  # notices, which is how logging gets turned off altogether.
  assert {
    condition     = google_compute_router_nat.this.log_config[0].enable && google_compute_router_nat.this.log_config[0].filter == "ERRORS_ONLY"
    error_message = "NAT errors must be logged; translations should not be, or the logs get switched off for volume."
  }
}
