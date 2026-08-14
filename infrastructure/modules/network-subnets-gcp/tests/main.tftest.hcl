# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every Google API call.
#
# The assertions are about the properties the rest of the stack assumes,
# not about terraform's ability to create a subnet.

mock_provider "google" {}

variables {
  name        = "shomer-test"
  environment = "test"
  region      = "europe-west1"
  project     = "shomer-test"
  network_id  = "projects/shomer-test/global/networks/shomer-test"

  subnets = {
    workload = { cidr = "10.10.0.0/20", purpose = "workload" }
    proxy    = { cidr = "10.10.16.0/24", purpose = "egress" }
    lb       = { cidr = "10.10.17.0/24", purpose = "public-lb" }
  }

  pods_cidr     = "10.20.0.0/16"
  services_cidr = "10.30.0.0/20"
}

run "private_google_access_is_on_everywhere" {
  command = plan

  # This is what makes "no internet" survivable rather than fatal. Without
  # it an instance with no external IP and no NAT cannot reach Google's own
  # APIs — no image pull from Artifact Registry, no logging, and a GKE node
  # that never joins. The usual reaction to that symptom is to attach a NAT
  # to the workload subnet, which is precisely the hole this layout exists
  # to avoid, so the fix has to be here and it has to be on by default.
  assert {
    condition     = alltrue([for s in google_compute_subnetwork.this : s.private_ip_google_access])
    error_message = "A subnet without private Google access and without a NAT cannot pull an image or join a cluster — and the obvious remedy is to add the NAT this design refuses."
  }
}

run "only_the_workload_subnet_carries_pod_ranges" {
  command = plan

  # GKE takes its pod and service ranges from the subnet the nodes sit in.
  # Ranges on another subnet would make it a second place pods could be
  # scheduled — quietly, and outside whatever the firewall says about the
  # workload range.
  assert {
    condition     = length(google_compute_subnetwork.this["workload"].secondary_ip_range) == 2
    error_message = "The workload subnet must carry exactly the pod and service ranges."
  }

  assert {
    condition = alltrue([
      for k in ["proxy", "lb"] : length(google_compute_subnetwork.this[k].secondary_ip_range) == 0
    ])
    error_message = "Only the workload subnet may carry secondary ranges."
  }

  # GKE refers to these by name and fails cluster creation with an
  # unhelpful "range not found" when they disagree.
  assert {
    condition = alltrue([
      for r in google_compute_subnetwork.this["workload"].secondary_ip_range :
      contains(["shomer-test-pods", "shomer-test-services"], r.range_name)
    ])
    error_message = "The secondary ranges must be named as the outputs claim, or the cluster unit asks for ranges that do not exist."
  }
}

run "two_workload_subnets_are_refused" {
  command = plan

  variables {
    subnets = {
      workload = { cidr = "10.10.0.0/20", purpose = "workload" }
      other    = { cidr = "10.10.32.0/20", purpose = "workload" }
      proxy    = { cidr = "10.10.16.0/24", purpose = "egress" }
    }
  }

  # Two would each get the same pod range name and create a second place
  # pods could run, outside the firewall rules written for the first.
  expect_failures = [var.subnets]
}

run "an_unknown_purpose_is_refused" {
  command = plan

  variables {
    subnets = {
      workload = { cidr = "10.10.0.0/20", purpose = "workload" }
      odd      = { cidr = "10.10.16.0/24", purpose = "database" }
    }
  }

  # The routes and firewall units branch on `purpose`. An unrecognised
  # value there does not error in those modules — it simply matches no
  # branch, so the subnet silently gets no rules and no route, which reads
  # as "isolated by design" rather than as a typo.
  expect_failures = [var.subnets]
}

run "flow_log_sampling_cannot_be_zero" {
  command = plan

  variables {
    flow_logs_sampling = 0
  }

  # Zero produces a log config that exists, reports as enabled, and records
  # nothing. That is worse than switching flow logs off, which at least
  # leaves no false assurance behind.
  expect_failures = [var.flow_logs_sampling]
}

run "the_outputs_name_the_workload_subnet" {
  command = plan

  # The cluster unit asks this module which subnet pods run in rather than
  # hardcoding a key, so that renaming a subnet in the config cannot leave
  # the cluster pointed at a subnet that no longer exists.
  assert {
    condition     = output.workload_subnet == "workload"
    error_message = "The workload subnet must be discoverable from the outputs."
  }
}
