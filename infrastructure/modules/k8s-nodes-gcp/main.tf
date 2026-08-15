# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The node pool pods actually run on.
#
# Separate from the cluster because a pool created with the cluster cannot
# be reconfigured without replacing the cluster — so every real pool lives
# here, where changing a machine type is a rolling replacement rather than
# a rebuild.
#
# THE NETWORK TAG IS THE LOAD-BEARING LINE IN THIS FILE. Both
# services/network/routes and services/network/firewall key on it: it is
# what sends these nodes' egress to the proxy and what permits them to
# reach it. A pool without it builds, joins, runs pods, and can reach
# nothing outside the VPC — with no error anywhere that says why.

locals {
  # Derived rather than read back from the resource. The format is fixed —
  # <account_id>@<project>.iam.gserviceaccount.com — and the attribute is
  # computed, so building the node config from it would make "do the nodes
  # run as their own identity?" unanswerable at plan and in tests.
  sa_email = "${var.name}-node@${var.project}.iam.gserviceaccount.com"

  # Spread across every zone in production, one in staging. This is the
  # difference between a zone failure costing capacity and costing the
  # cluster.
  zones = var.ha ? var.zones : slice(var.zones, 0, 1)

  min = var.ha ? var.min_nodes_ha : 1
  max = var.ha ? var.max_nodes_ha : var.max_nodes
}

# Its own identity, holding only what a node needs to join and report. The
# default compute service account carries project editor in most projects,
# and every pod that reads the node's token would inherit it.
resource "google_service_account" "nodes" {
  project      = var.project
  account_id   = "${var.name}-node"
  display_name = "GKE nodes — ${var.environment}"
  description  = "Runs the node pool. Holds only logging, monitoring and image pull."
}

resource "google_project_iam_member" "nodes" {
  for_each = toset(var.node_roles)

  project = var.project
  role    = each.value
  member  = "serviceAccount:${local.sa_email}"

  depends_on = [google_service_account.nodes]
}

resource "google_container_node_pool" "this" {
  name     = var.name
  project  = var.project
  location = var.region
  cluster  = var.cluster_name

  node_locations = local.zones

  # Per zone, not in total. A node count that reads as the fleet size and
  # is per zone is how a three-zone production ends up with three times the
  # bill somebody approved.
  initial_node_count = local.min

  autoscaling {
    min_node_count = local.min
    max_node_count = local.max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    # One extra node at a time, none taken away first. surge 0 with
    # max_unavailable 1 would drain a node before its replacement exists,
    # which on a small pool is a capacity cliff during every upgrade.
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-balanced"
    image_type   = "COS_CONTAINERD"

    service_account = local.sa_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # THE TAG. See the header — without it these nodes have no route out
    # and no permission to reach the proxy, and nothing says so.
    tags = [var.workload_tag]

    labels = merge({
      environment = var.environment
    }, var.tags)

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # The same control as requiring IMDSv2 on the proxy: without it a pod
    # reads the node's metadata server and takes the node's token, so every
    # pod holds whatever the node can do.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  lifecycle {
    ignore_changes = [initial_node_count]

    precondition {
      condition     = length(local.zones) > 0
      error_message = "A pool with no zones creates no nodes and reports success."
    }

    precondition {
      condition     = local.max >= local.min
      error_message = "The autoscaler's ceiling is below its floor."
    }
  }
}
