# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every Google API call.
#
# The assertion that carries this module is one string, and what it means
# is the opposite of the AWS module's: there, Cilium must be allowed in;
# here, it is already the platform and a second one must be kept out.

mock_provider "google" {}

variables {
  name                = "shomer-test"
  environment         = "test"
  region              = "europe-west1"
  project             = "shomer-test"
  network_id          = "projects/shomer-test/global/networks/shomer-test"
  subnetwork          = "projects/shomer-test/regions/europe-west1/subnetworks/shomer-test-workload"
  pods_range_name     = "shomer-test-pods"
  services_range_name = "shomer-test-services"

  master_authorized_cidrs = [
    { cidr = "10.10.0.0/16", name = "vpc" },
  ]
}

run "the_dataplane_is_cilium" {
  command = plan

  # ADVANCED_DATAPATH is Dataplane V2, which IS Cilium — eBPF, managed by
  # Google, replacing kube-proxy. The legacy datapath drops eBPF policy
  # enforcement, and installing upstream Cilium alongside this one leaves
  # two dataplanes programming the same pods, where a policy that appears
  # applied may not be what decides the packet.
  assert {
    condition     = google_container_cluster.this.datapath_provider == "ADVANCED_DATAPATH"
    error_message = "Without Dataplane V2 there is no eBPF policy enforcement, and adding upstream Cilium would give the cluster two dataplanes."
  }

  # Redundant with Dataplane V2 and stated anyway, so that switching the
  # datapath back does not silently take policy enforcement with it.
  assert {
    condition     = google_container_cluster.this.network_policy[0].enabled
    error_message = "Policy enforcement should not depend on the datapath setting alone."
  }

  assert {
    condition     = output.dataplane == "cilium-dataplane-v2"
    error_message = "A plan should say what enforces policy in this cluster."
  }
}

run "the_nodes_and_the_api_are_both_private" {
  command = plan

  assert {
    condition     = google_container_cluster.this.private_cluster_config[0].enable_private_nodes
    error_message = "A node with a public address is a way to the internet that bypasses the proxy."
  }

  # This is the Kubernetes API, not the applications. The load balancer
  # that serves the api and the ssr is a different front door, decided by
  # public_load_balancer in the environment config.
  assert {
    condition     = google_container_cluster.this.private_cluster_config[0].enable_private_endpoint
    error_message = "A public Kubernetes API endpoint is reachable from the internet regardless of what the load balancer does."
  }
}

run "pods_get_their_own_identity" {
  command = plan

  # Without workload identity every pod on a node has whatever that node
  # can do, which is the coarsest grant available and invisible in any
  # Kubernetes manifest.
  assert {
    condition     = google_container_cluster.this.workload_identity_config[0].workload_pool == "shomer-test.svc.id.goog"
    error_message = "Without workload identity, a pod borrows the node's permissions."
  }
}

run "the_default_node_pool_is_removed" {
  command = plan

  # A pool created with the cluster cannot be changed without replacing the
  # cluster, so the real ones live in services/k8s/nodes.
  assert {
    condition     = google_container_cluster.this.remove_default_node_pool
    error_message = "A default pool left in place cannot be reconfigured without replacing the cluster."
  }
}

run "the_secondary_ranges_are_named_as_the_subnets_unit_published_them" {
  command = plan

  # GKE refers to these by name and fails creation with an unhelpful
  # "range not found" when they disagree.
  assert {
    condition     = google_container_cluster.this.ip_allocation_policy[0].cluster_secondary_range_name == "shomer-test-pods" && google_container_cluster.this.ip_allocation_policy[0].services_secondary_range_name == "shomer-test-services"
    error_message = "The range names must match what services/network/subnets created."
  }
}

run "an_unauthorised_api_is_refused" {
  command = plan

  variables {
    master_authorized_cidrs = []
  }

  # A private endpoint with no authorized networks is reachable by nothing,
  # including the pipeline that manages it.
  expect_failures = [google_container_cluster.this]
}

run "authorising_the_world_is_refused" {
  command = plan

  variables {
    master_authorized_cidrs = [{ cidr = "0.0.0.0/0", name = "everywhere" }]
  }

  # The private endpoint would refuse it anyway, which makes this a
  # confusing no-op rather than a working setting — and a dangerous one the
  # day somebody enables the public endpoint.
  expect_failures = [var.master_authorized_cidrs]
}

run "the_legacy_datapath_is_refused" {
  command = plan

  variables {
    datapath_provider_override = "LEGACY_DATAPATH"
  }

  expect_failures = [google_container_cluster.this]
}

run "a_master_range_of_the_wrong_size_is_refused" {
  command = plan

  variables {
    master_cidr = "172.16.0.0/24"
  }

  # GKE accepts only a /28, and it cannot be changed after creation.
  expect_failures = [var.master_cidr]
}
