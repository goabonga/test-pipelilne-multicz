# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every Google API call.
#
# Half of these assert properties of the rendered Squid config, because
# that file is where "the proxy is the only way out" turns from a network
# arrangement into a policy — and a permissive line in it undoes everything
# upstream without changing a single resource.

mock_provider "google" {}

variables {
  name            = "shomer-test-proxy"
  environment     = "test"
  region          = "europe-west1"
  project         = "shomer-test"
  network_id      = "projects/shomer-test/global/networks/shomer-test"
  subnetwork      = "projects/shomer-test/regions/europe-west1/subnetworks/shomer-test-proxy"
  zones           = ["europe-west1-b"]
  client_cidrs    = ["10.10.0.0/20"]
  allowed_domains = [".debian.org", ".googleapis.com"]
}

run "the_instances_have_no_external_address" {
  command = plan

  # An external address is a way to the internet that bypasses the NAT. The
  # proxies would still work — that is the danger — and the addresses the
  # world sees would silently stop being the reserved ones, breaking every
  # external allow-list with nothing to point at.
  assert {
    condition = alltrue([
      for ni in google_compute_instance_template.proxy.network_interface :
      length(ni.access_config) == 0
    ])
    error_message = "An access_config assigns an external address, and the fleet would stop being seen from the reserved egress addresses."
  }
}

run "the_fleet_carries_the_capability_tag" {
  command = plan

  # routes and firewall both key on this tag, so it is what grants the
  # instance the internet. Without it the fleet is built, healthy, and
  # unable to reach anything.
  assert {
    condition     = contains(google_compute_instance_template.proxy.tags, "egress-proxy")
    error_message = "Without the tag the proxies match neither the route nor the firewall rule, and the whole estate loses egress."
  }
}

run "the_fleet_does_not_borrow_the_default_identity" {
  command = plan

  # The default compute service account carries project editor in most
  # projects. Borrowing it would let a host whose entire job is talking to
  # the internet read every bucket and change every resource.
  assert {
    condition = alltrue([
      for sa in google_compute_instance_template.proxy.service_account :
      sa.email == "shomer-test-proxy-sa@shomer-test.iam.gserviceaccount.com"
    ])
    error_message = "The proxies must run as their own identity, not the project default."
  }

  # cloud-platform would let any process on the box use the full API
  # surface the account is granted; these two cover logs and metrics.
  assert {
    condition = alltrue([
      for sa in google_compute_instance_template.proxy.service_account :
      !contains(sa.scopes, "https://www.googleapis.com/auth/cloud-platform")
    ])
    error_message = "cloud-platform is not a scope for a machine that exists to talk to the internet on behalf of others."
  }
}

run "the_rendered_config_denies_by_default" {
  command = plan

  # THE assertion in this module. Squid evaluates http_access in order, so
  # a trailing `deny all` is what makes the allow above it a list rather
  # than a suggestion. Without it, everything not explicitly denied is
  # forwarded.
  assert {
    condition     = can(regex("http_access deny all", local.squid_conf))
    error_message = "Without a trailing deny, Squid forwards everything the rules above did not explicitly refuse."
  }

  assert {
    condition     = can(regex("http_access allow workload allowed", local.squid_conf))
    error_message = "The allow must require both the client range and the destination list, not either."
  }

  # The order is the policy. An allow placed before these denies would let
  # a CONNECT to any port through, which is a tunnel out for any protocol.
  assert {
    condition     = index(split("\n", local.squid_conf), "http_access deny !Safe_ports") < index(split("\n", local.squid_conf), "http_access allow workload allowed")
    error_message = "The port denies must come before the allow, or a CONNECT to any port is forwarded."
  }
}

run "the_rendered_config_names_this_environments_clients_and_destinations" {
  command = plan

  assert {
    condition     = can(regex("acl workload src 10\\.10\\.0\\.0/20", local.squid_conf))
    error_message = "The client range from the environment config must reach the rendered file."
  }

  assert {
    condition     = can(regex("acl allowed dstdomain \\.debian\\.org", local.squid_conf))
    error_message = "The allow-list from the environment config must reach the rendered file."
  }

  # CONNECT hides the host from the default log format, and every HTTPS
  # request is a CONNECT — so a denied connection would be logged as an
  # address and a port, and "what was it trying to reach?" would be
  # guesswork exactly when it matters.
  assert {
    condition     = can(regex("logformat shomer", local.squid_conf))
    error_message = "The default log format omits the requested host on CONNECT, which is every HTTPS request."
  }
}

run "an_empty_allow_list_is_refused" {
  command = plan

  variables {
    allowed_domains = []
  }

  # Safe and useless. There is no permissive default either — naming what
  # the estate may reach is the point of having a proxy at all.
  expect_failures = [var.allowed_domains]
}

run "an_allow_all_domain_is_refused" {
  command = plan

  variables {
    allowed_domains = ["."]
  }

  # `.` matches every domain. It would pass review as a list of one entry
  # and turn the fleet into a router.
  expect_failures = [var.allowed_domains]
}

run "the_world_cannot_be_a_client" {
  command = plan

  variables {
    client_cidrs = ["0.0.0.0/0"]
  }

  # An open relay for anything that can reach it.
  expect_failures = [var.client_cidrs]
}

run "ha_runs_more_than_one" {
  command = plan

  variables {
    ha    = true
    zones = ["europe-west1-b", "europe-west1-c"]
  }

  assert {
    condition     = google_compute_region_instance_group_manager.proxy.target_size == 2
    error_message = "With ha on, a restart or a zone failure must not be an outage for everything behind the proxy."
  }

  # A rolling replace that dips to zero is an outage for the whole estate's
  # egress, briefly and completely.
  assert {
    condition     = google_compute_region_instance_group_manager.proxy.update_policy[0].max_unavailable_fixed == 0
    error_message = "The update policy must never take the fleet below its current size."
  }
}

run "staging_runs_one_and_says_so" {
  command = plan

  assert {
    condition     = google_compute_region_instance_group_manager.proxy.target_size == 1
    error_message = "Without ha the fleet is one instance — a single point of failure for the estate's egress, which is a decision rather than an accident."
  }
}
