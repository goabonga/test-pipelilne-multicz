# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every Google API call.

mock_provider "google" {}

variables {
  name         = "shomer-test-pool"
  environment  = "test"
  region       = "europe-west1"
  project      = "shomer-test"
  cluster_name = "shomer-test"
  zones        = ["europe-west1-b", "europe-west1-c", "europe-west1-d"]
}

run "the_nodes_carry_the_tag_that_sends_them_through_the_proxy" {
  command = plan

  # THE assertion. routes and firewall both key on this tag. Without it a
  # pool builds, joins, runs pods and can reach nothing outside the VPC,
  # with no error anywhere that says why — which is a far worse failure
  # than one that refuses to start.
  assert {
    condition = alltrue([
      for nc in google_container_node_pool.this.node_config : contains(nc.tags, "workload")
    ])
    error_message = "Without the workload tag these nodes match neither the route to the proxy nor the rule permitting it."
  }
}

run "the_nodes_do_not_borrow_the_default_identity" {
  command = plan

  assert {
    condition = alltrue([
      for nc in google_container_node_pool.this.node_config :
      nc.service_account == "shomer-test-pool-node@shomer-test.iam.gserviceaccount.com"
    ])
    error_message = "The default compute account carries project editor in most projects, and anything reading the node's token inherits it."
  }

  # Write logs, write metrics, pull images. Nothing else.
  assert {
    condition     = !contains(var.node_roles, "roles/editor") && !contains(var.node_roles, "roles/owner")
    error_message = "editor on the node identity means every pod that can read the node's token can change the project."
  }
}

run "a_pod_cannot_read_the_nodes_token" {
  command = plan

  # The same control as requiring IMDSv2 on the proxy fleet. Without it the
  # workload identity arranged on the cluster is bypassable by anything
  # that can reach a link-local address.
  assert {
    condition = alltrue([
      for nc in google_container_node_pool.this.node_config :
      alltrue([for wmc in nc.workload_metadata_config : wmc.mode == "GKE_METADATA"])
    ])
    error_message = "Without GKE_METADATA a pod reads the node's metadata server and takes the node's token."
  }
}

run "ha_spreads_across_every_zone" {
  command = plan

  variables {
    ha = true
  }

  assert {
    condition     = length(google_container_node_pool.this.node_locations) == 3
    error_message = "With ha on, a zone failure should cost capacity rather than the cluster."
  }
}

run "without_ha_the_pool_is_one_zone_and_says_so" {
  command = plan

  assert {
    condition     = length(google_container_node_pool.this.node_locations) == 1
    error_message = "Without ha the pool runs in one zone — a decision rather than an accident."
  }

  assert {
    condition     = length(output.zones) == 1
    error_message = "A plan should say where the pool actually runs."
  }
}

run "an_upgrade_never_drains_before_replacing" {
  command = plan

  # surge 0 with max_unavailable 1 drains a node before its replacement
  # exists, which on a small pool is a capacity cliff during every upgrade.
  assert {
    condition = alltrue([
      for u in google_container_node_pool.this.upgrade_settings :
      u.max_surge == 1 && u.max_unavailable == 0
    ])
    error_message = "An upgrade must add a node before taking one away."
  }
}

run "an_over_privileged_node_identity_is_refused" {
  command = plan

  variables {
    node_roles = ["roles/editor"]
  }

  expect_failures = [var.node_roles]
}
