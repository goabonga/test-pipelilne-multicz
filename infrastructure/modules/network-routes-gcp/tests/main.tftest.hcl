# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every Google API call.
#
# This module is where "the workload cannot leave" stops being an intention
# and becomes a checkable absence. Most of what follows asserts that
# something does NOT exist, which is the only form the property can take.

mock_provider "google" {}

variables {
  name         = "shomer-test"
  environment  = "test"
  region       = "europe-west1"
  project      = "shomer-test"
  network_name = "shomer-test-network"
}

run "the_workload_has_no_way_out_until_the_proxy_exists" {
  command = plan

  # The resting state, and the one worth guarding. Creating this route with
  # some other next hop "for now" — the internet gateway, a placeholder
  # instance — would open exactly the path the design forbids, and it would
  # work, which is why it would survive review.
  assert {
    condition     = length(google_compute_route.workload_egress) == 0
    error_message = "With no proxy to point at, the workload nodes must have no default route at all."
  }

  assert {
    condition     = output.workload_has_egress == false
    error_message = "A plan should be able to say whether the workload can reach the internet without a reader inferring it from an absent resource."
  }
}

run "only_the_proxy_reaches_the_internet_directly" {
  command = plan

  # GCP routes are network-wide and selected by instance tag rather than by
  # subnet. The tag is the boundary: an instance without it does not match
  # this route whatever subnet it sits in.
  assert {
    condition     = google_compute_route.proxy_egress.tags == toset(["egress-proxy"])
    error_message = "The internet route must be restricted by tag. Untagged, it applies to every instance in the network."
  }

  assert {
    condition     = google_compute_route.proxy_egress.next_hop_gateway == "default-internet-gateway"
    error_message = "The proxy's route out must reach the gateway; anything else is not egress."
  }

  assert {
    condition     = google_compute_route.proxy_egress.dest_range == "0.0.0.0/0"
    error_message = "The proxy route must be the default route, not a subset someone has to keep extending."
  }
}

run "private_google_access_has_its_route" {
  command = plan

  # The subnets module sets private_ip_google_access, and that flag does
  # NOTHING without this route once the default route is deleted. The
  # symptom is a node that never joins and an image that never pulls, while
  # the flag reads as enabled in the console. Half of one feature,
  # configured in two modules.
  assert {
    condition     = google_compute_route.google_apis.dest_range == "199.36.153.8/30"
    error_message = "Without a route to Google's private API range, private_ip_google_access is inert and nothing says so."
  }

  # Untagged on purpose: every subnet needs to reach the APIs, including
  # the workload nodes that have no other route anywhere.
  assert {
    # Unset comes back as null rather than an empty set, and both mean
    # "applies to every instance".
    condition     = length(coalesce(google_compute_route.google_apis.tags, toset([]))) == 0
    error_message = "The Google API route must apply to every instance, or the workload nodes lose their only reachable destination."
  }

  # Lower number is higher priority. It has to beat the default route so
  # that API traffic does not take the long way through the proxy.
  assert {
    condition     = google_compute_route.google_apis.priority < google_compute_route.proxy_egress.priority
    error_message = "The API route must outrank the default route, or Google API traffic is sent to the proxy instead."
  }
}

run "the_workload_route_appears_once_the_proxy_does" {
  command = plan

  variables {
    proxy_ilb_address = "projects/shomer-test/regions/europe-west1/forwardingRules/shomer-test-proxy"
  }

  assert {
    condition     = length(google_compute_route.workload_egress) == 1
    error_message = "Given a proxy to point at, the workload must get its route."
  }

  # The whole point: the workload's default route goes to the proxy, never
  # to a gateway.
  assert {
    condition     = google_compute_route.workload_egress[0].next_hop_ilb != "" && google_compute_route.workload_egress[0].next_hop_gateway == null
    error_message = "The workload's way out must be the proxy. A gateway here would make the proxy optional, and optional means bypassed."
  }

  assert {
    condition     = google_compute_route.workload_egress[0].tags == toset(["workload"])
    error_message = "The workload route must be tag-scoped, or it applies to the proxies too and loops their traffic back at themselves."
  }

  # The two tags must differ, or an instance matches both routes and which
  # one wins is a priority tie-break rather than a decision.
  assert {
    condition     = var.proxy_tag != var.workload_tag
    error_message = "The proxy and workload tags must differ, or every instance matches both routes."
  }
}

run "a_malformed_api_range_is_refused" {
  command = plan

  variables {
    google_apis_cidr = "199.36.153.8"
  }

  expect_failures = [var.google_apis_cidr]
}
