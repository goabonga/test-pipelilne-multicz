# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Every path off this network, in one file.
#
# The VPC was created with `delete_default_routes_on_create`, so it has no
# 0.0.0.0/0 at all. This module puts back exactly the ones that are wanted
# and nothing else, which is why a reviewer can answer "how does traffic
# leave?" by reading one module rather than by auditing a network.
#
# GCP routes are network-wide and selected by instance tag, not by subnet.
# That is the mechanism the separation rests on here: the proxy instances
# carry one tag and reach the internet gateway; the workload nodes carry
# another and reach only the proxy. An instance with neither tag has no
# default route at all.

# THE ROUTE THAT MAKES PRIVATE GOOGLE ACCESS ACTUALLY WORK.
#
# The subnets module sets private_ip_google_access, but that setting alone
# does nothing without a route to Google's API range: with the default
# route deleted, packets to private.googleapis.com have nowhere to go.
#
# The symptom is a node that never joins, an image that never pulls and no
# logs explaining either — and the flag that was supposed to prevent it
# reads as enabled in the console. This route is half of that feature and
# they are configured in different modules.
resource "google_compute_route" "google_apis" {
  name        = "${var.name}-google-apis"
  project     = var.project
  network     = var.network_name
  description = "private.googleapis.com — the other half of private_ip_google_access"

  dest_range       = var.google_apis_cidr
  next_hop_gateway = "default-internet-gateway"
  priority         = 100
}

# The proxy fleet, and only the proxy fleet, reaches the internet directly.
# Tag-scoped: an instance without this tag does not match, whatever subnet
# it sits in.
resource "google_compute_route" "proxy_egress" {
  name        = "${var.name}-proxy-egress"
  project     = var.project
  network     = var.network_name
  description = "The one route to the internet. Restricted by tag to the egress proxies."

  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  tags             = [var.proxy_tag]
  priority         = 1000
}

# THE WORKLOAD DEFAULT ROUTE IS ABSENT UNTIL THE PROXY EXISTS, AND THAT IS
# THE INTENDED RESTING STATE.
#
# Until services/vms/proxy has an internal load balancer to point at, the
# workload nodes have no 0.0.0.0/0 whatsoever. They can still reach the
# subnets they are peered with and Google's APIs through the route above;
# they cannot reach anything else.
#
# Creating this route with some other next hop "for now" — the internet
# gateway, a placeholder instance — would open the exact path the design
# forbids, and it would work, which is why it would survive review.
resource "google_compute_route" "workload_egress" {
  count = var.proxy_ilb_address == null ? 0 : 1

  name        = "${var.name}-workload-egress"
  project     = var.project
  network     = var.network_name
  description = "Workload egress, via the proxy's internal load balancer. The only way out for tagged workload nodes."

  dest_range   = "0.0.0.0/0"
  next_hop_ilb = var.proxy_ilb_address
  tags         = [var.workload_tag]
  priority     = 1000
}
