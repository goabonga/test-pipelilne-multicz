# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every Google API call.
#
# Firewall rules are the easiest thing in an infrastructure to get subtly
# wrong and the hardest to notice: a rule that is too wide does not fail,
# it works better. These assert the narrowness rather than the presence.

mock_provider "google" {}

variables {
  name              = "shomer-test"
  environment       = "test"
  region            = "europe-west1"
  project           = "shomer-test"
  network_name      = "shomer-test-network"
  proxy_subnet_cidr = "10.10.16.0/24"
  internal_ranges   = ["10.10.0.0/16", "10.20.0.0/16", "10.30.0.0/20"]
}

run "egress_is_denied_before_anything_is_allowed" {
  command = plan

  # THE rule. GCP's implied policy is deny-ingress and ALLOW-EGRESS, so a
  # network with no firewall rules permits every outbound connection from
  # every instance. "Not configured yet" is an open state on GCP and looks
  # exactly like a closed one.
  assert {
    condition     = google_compute_firewall.deny_all_egress.direction == "EGRESS"
    error_message = "The deny must be on egress. GCP already denies ingress; egress is the half that is open by default."
  }

  assert {
    condition     = google_compute_firewall.deny_all_egress.destination_ranges == toset(["0.0.0.0/0"])
    error_message = "The deny must cover everything, or the gaps are permitted by GCP's implied allow."
  }

  # Lower number wins. Every allow in this module must outrank the deny, or
  # the deny swallows them and nothing works — which at least fails loudly.
  # The dangerous direction is the other one: a deny that outranks nothing.
  assert {
    condition = alltrue([
      for r in [
        google_compute_firewall.proxy_egress,
        google_compute_firewall.workload_to_proxy,
        google_compute_firewall.google_apis_egress,
      ] : r.priority < google_compute_firewall.deny_all_egress.priority
    ])
    error_message = "Every allow must outrank the deny."
  }
}

run "the_workload_may_reach_the_proxy_and_nothing_else" {
  command = plan

  # Not 0.0.0.0/0 "through the proxy" — the proxy's range, on the proxy's
  # port. A workload that finds another route still cannot use it, which is
  # the difference between a routing decision and a permission.
  assert {
    condition     = google_compute_firewall.workload_to_proxy.destination_ranges == toset(["10.10.16.0/24"])
    error_message = "The workload's egress rule must name the proxy subnet. Anything wider makes the route the only control."
  }

  assert {
    condition = alltrue([
      for a in google_compute_firewall.workload_to_proxy.allow : toset(a.ports) == toset(["3128"])
    ])
    error_message = "The workload may reach the proxy on the proxy port only."
  }

  # The narrowest and most valuable check here: no rule anywhere in this
  # module lets the workload tag reach the internet.
  assert {
    condition = alltrue([
      for r in [
        google_compute_firewall.proxy_egress,
        google_compute_firewall.workload_to_proxy,
        google_compute_firewall.google_apis_egress,
        google_compute_firewall.internal_egress,
      ] :
      !(contains(coalesce(r.target_tags, toset([])), "workload") && contains(coalesce(r.destination_ranges, toset([])), "0.0.0.0/0"))
    ])
    error_message = "A rule lets the workload tag reach 0.0.0.0/0. That is the one thing this whole design forbids."
  }
}

run "only_the_proxy_reaches_the_internet_and_only_on_web_ports" {
  command = plan

  assert {
    condition     = google_compute_firewall.proxy_egress.target_tags == toset(["egress-proxy"])
    error_message = "The internet rule must be scoped to the proxy tag. Untargeted, it applies to every instance."
  }

  # A proxy that can open any port is a tunnel out for everything that can
  # reach it, which is most of the estate.
  assert {
    condition = alltrue([
      for a in google_compute_firewall.proxy_egress.allow : toset(a.ports) == toset(["80", "443"])
    ])
    error_message = "The proxy's own egress must be limited to the ports it proxies."
  }
}

run "the_ranges_that_are_not_the_internet_are_the_documented_ones" {
  command = plan

  # These look public and are not: they belong to Google's health checkers.
  # A backend that refuses them is marked unhealthy and taken out of
  # service, which presents as an outage with no failing request to inspect.
  assert {
    condition     = google_compute_firewall.health_checks.source_ranges == toset(["35.191.0.0/16", "130.211.0.0/22"])
    error_message = "The health check ranges must be Google's published ones, or every backend is marked unhealthy."
  }

  # The tunnel front-end. There is no bastion and no port 22 on the
  # internet; the tunnel authenticates against IAM before forwarding.
  assert {
    condition     = google_compute_firewall.tunnel_ingress[0].source_ranges == toset(["35.235.240.0/20"])
    error_message = "The tunnel rule must name Google's IAP range and nothing wider — it is the only inbound path to an instance."
  }
}

run "the_internet_cannot_be_declared_internal" {
  command = plan

  variables {
    internal_ranges = ["10.10.0.0/16", "0.0.0.0/0"]
  }

  # The quiet way to undo this entire module: widen "internal" until it
  # includes everything. The internal rules are allows, so this permits
  # every outbound connection while every other rule in the file still
  # reads as strict.
  expect_failures = [var.internal_ranges]
}

run "denied_egress_is_logged" {
  command = plan

  # A refused outbound connection is the signal that something is trying to
  # leave another way, and this is the only place that attempt is recorded.
  assert {
    condition     = length(google_compute_firewall.deny_all_egress.log_config) == 1
    error_message = "Denied egress must be logged, or an attempt to bypass the proxy leaves no trace at all."
  }
}
