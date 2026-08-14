# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Three subnets, and the separation between them is the design.
#
#   workload   where pods run. No NAT, no route out. Its only way off the
#              network is the proxy, and that is enforced by what
#              services/network/routes does NOT create for it.
#   proxy      the Squid fleet. The one subnet with a path to the internet.
#   lb         the load balancer front-end.
#
# GCP subnets are regional, so there is one of each regardless of how many
# zones the environment spreads across. That is the opposite of AWS, where
# a subnet lives in one zone and this module's counterpart creates one per
# purpose per zone.

locals {
  # The workload subnet is the only one that carries pod and service
  # ranges: GKE demands them as secondary ranges on the subnet the nodes
  # sit in, and putting them anywhere else would silently create a second
  # eligible subnet for scheduling.
  workload_names = [for k, v in var.subnets : k if v.purpose == "workload"]
}

resource "google_compute_subnetwork" "this" {
  for_each = var.subnets

  name    = "${var.name}-${each.key}"
  project = var.project
  region  = var.region
  network = var.network_id

  ip_cidr_range = each.value.cidr

  # PRIVATE GOOGLE ACCESS IS WHAT MAKES "NO INTERNET" SURVIVABLE.
  #
  # Without it, an instance with no external IP and no NAT cannot reach
  # Google's own APIs — which means no image pull from Artifact Registry,
  # no logging, no monitoring, and a GKE node that never joins. The usual
  # reaction is to attach a NAT to the workload subnet, which is exactly
  # the hole this layout exists to avoid.
  #
  # It routes to Google's APIs over internal addresses. It is not a path to
  # the internet: nothing else is reachable through it.
  private_ip_google_access = true

  # Secondary ranges only where pods actually run.
  dynamic "secondary_ip_range" {
    for_each = each.value.purpose == "workload" ? [1] : []
    content {
      range_name    = "${var.name}-pods"
      ip_cidr_range = var.pods_cidr
    }
  }

  dynamic "secondary_ip_range" {
    for_each = each.value.purpose == "workload" ? [1] : []
    content {
      range_name    = "${var.name}-services"
      ip_cidr_range = var.services_cidr
    }
  }

  # A private network with no egress still needs a record of what tried to
  # leave. Sampling rather than every packet: the full rate on a busy
  # subnet costs more than the incidents it catches, and 0.5 still shows a
  # pattern of attempts.
  dynamic "log_config" {
    for_each = var.flow_logs_enabled ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = var.flow_logs_sampling
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }

}
