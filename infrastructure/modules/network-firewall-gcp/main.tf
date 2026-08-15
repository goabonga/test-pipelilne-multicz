# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The packet-level half of "nothing leaves except through the proxy".
#
# services/network/routes removed the ways out. This removes the permission
# to use one, which is not the same thing: a route is a path, a firewall
# rule is an authorisation, and closing only one of them leaves the other
# as the single point of failure.
#
# GCP'S IMPLIED RULES ARE DENY-INGRESS AND ALLOW-EGRESS.
#
# That second half is the trap this module exists for. A network with no
# firewall rules at all permits every outbound connection from every
# instance — so "we have not configured the firewall yet" is not a closed
# state on GCP, it is an open one, and it looks identical to a network
# whose rules are still being written.
#
# Everything below is built around one low-priority deny that turns the
# implied allow off, with narrow allows above it.

locals {
  # Lower number wins. The deny sits just above GCP's own implied rules so
  # that every allow in this file outranks it, and anything not named here
  # is refused.
  priority_deny  = 65000
  priority_allow = 1000

  # Google's load balancer health checkers. Traffic from these ranges is
  # not from the internet — it originates inside Google's infrastructure —
  # and a backend that refuses it is marked unhealthy and taken out of
  # service, which presents as an outage with no failing request to look at.
  health_check_ranges = ["35.191.0.0/16", "130.211.0.0/22"]

  # Identity-Aware Proxy TCP forwarding. This is how a human reaches a
  # private instance under `access.method = control-plane-tunnel`: there is
  # no bastion host, the tunnel authenticates against IAM, and the right to
  # connect is a grant that can be revoked centrally and appears in the
  # audit log.
  iap_range = "35.235.240.0/20"
}

# ── the rule that makes every other rule mean something ─────────────────

resource "google_compute_firewall" "deny_all_egress" {
  name        = "${var.name}-deny-egress"
  project     = var.project
  network     = var.network_name
  description = "Turns off GCP's implied allow-egress. Without this, every allow below is decoration."

  direction = "EGRESS"
  priority  = local.priority_deny

  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]

  # Logged because a refused outbound connection is the signal that
  # something is trying to leave another way, and it is the only place that
  # attempt is recorded.
  dynamic "log_config" {
    for_each = var.logging_enabled ? [1] : []
    content {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }
}

# ── what is allowed out, and by whom ────────────────────────────────────

# The proxies, and only the proxies. Everything else in this file routes
# through them.
resource "google_compute_firewall" "proxy_egress" {
  name        = "${var.name}-proxy-egress"
  project     = var.project
  network     = var.network_name
  description = "The egress proxies reach the internet. Nothing else may."

  direction          = "EGRESS"
  priority           = local.priority_allow
  target_tags        = [var.proxy_tag]
  destination_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = var.proxy_egress_ports
  }
}

# The workload's ONLY permitted destination outside its own subnet. Not
# 0.0.0.0/0 through the proxy — the proxy's address, on the proxy's port.
# A workload that finds another route still cannot use it.
resource "google_compute_firewall" "workload_to_proxy" {
  name        = "${var.name}-workload-to-proxy"
  project     = var.project
  network     = var.network_name
  description = "Workload egress, to the proxy and nowhere else."

  direction          = "EGRESS"
  priority           = local.priority_allow
  target_tags        = [var.workload_tag]
  destination_ranges = [var.proxy_subnet_cidr]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.proxy_port)]
  }
}

# Google's own APIs over internal addresses. The counterpart of the route
# in services/network/routes: the route makes the destination reachable,
# this makes it permitted, and both are required.
resource "google_compute_firewall" "google_apis_egress" {
  name        = "${var.name}-google-apis-egress"
  project     = var.project
  network     = var.network_name
  description = "Artifact Registry, logging, monitoring — over private addresses, not the internet."

  direction          = "EGRESS"
  priority           = local.priority_allow
  destination_ranges = [var.google_apis_cidr]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

# Node-to-node and pod-to-pod. A cluster whose nodes cannot talk to each
# other does not form, and the failure looks like a control plane problem.
resource "google_compute_firewall" "internal" {
  name        = "${var.name}-internal"
  project     = var.project
  network     = var.network_name
  description = "Traffic inside the VPC, including the pod and service ranges."

  direction = "INGRESS"
  priority  = local.priority_allow

  source_ranges = var.internal_ranges

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "internal_egress" {
  name        = "${var.name}-internal-egress"
  project     = var.project
  network     = var.network_name
  description = "The egress half of the rule above. The deny below applies to internal destinations too."

  direction          = "EGRESS"
  priority           = local.priority_allow
  destination_ranges = var.internal_ranges

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}

# ── what is allowed in ──────────────────────────────────────────────────

# Health checks. Not internet traffic despite the public-looking source:
# these ranges belong to Google's own checkers, and refusing them takes
# every backend out of service with no failing request to point at.
resource "google_compute_firewall" "health_checks" {
  name        = "${var.name}-health-checks"
  project     = var.project
  network     = var.network_name
  description = "Google's load balancer health checkers. Refusing these marks every backend unhealthy."

  direction     = "INGRESS"
  priority      = local.priority_allow
  source_ranges = local.health_check_ranges
  target_tags   = [var.workload_tag, var.proxy_tag]

  allow {
    protocol = "tcp"
  }
}

# The way a human gets in, with no host exposed and no port 22 on the
# internet. The source is Google's tunnel front-end, and the tunnel itself
# checks IAM before forwarding anything.
resource "google_compute_firewall" "tunnel_ingress" {
  count = var.tunnel_ingress_enabled ? 1 : 0

  name        = "${var.name}-tunnel-ingress"
  project     = var.project
  network     = var.network_name
  description = "IAP TCP forwarding. The only inbound path to an instance, and it authenticates first."

  direction     = "INGRESS"
  priority      = local.priority_allow
  source_ranges = [local.iap_range]

  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }

  dynamic "log_config" {
    for_each = var.logging_enabled ? [1] : []
    content {
      metadata = "INCLUDE_ALL_METADATA"
    }
  }
}
