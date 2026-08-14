# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every AWS call.
#
# Most of these are about the address arithmetic, because it is the part
# that fails silently: overlapping subnets are accepted by AWS at creation
# and surface later as traffic arriving at the wrong place.

mock_provider "aws" {}

variables {
  name        = "shomer-test"
  environment = "test"
  region      = "eu-west-3"
  vpc_id      = "vpc-0123456789abcdef0"
  zones       = ["eu-west-3a"]

  subnets = {
    workload = { cidr = "10.10.0.0/20", purpose = "workload" }
    proxy    = { cidr = "10.10.16.0/24", purpose = "egress" }
    lb       = { cidr = "10.10.17.0/24", purpose = "public-lb" }
  }
}

run "one_zone_takes_each_range_whole" {
  command = plan

  # Staging. With a single zone there is nothing to divide, and splitting
  # anyway would waste half of every range for no benefit.
  assert {
    condition     = length(aws_subnet.this) == 3
    error_message = "Three purposes across one zone is three subnets."
  }

  assert {
    condition     = aws_subnet.this["workload-eu-west-3a"].cidr_block == "10.10.0.0/20"
    error_message = "A single zone must receive the purpose's range unchanged."
  }
}

run "three_zones_divide_each_range_without_overlap" {
  command = plan

  variables {
    zones = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
  }

  assert {
    condition     = length(aws_subnet.this) == 9
    error_message = "Three purposes across three zones is nine subnets."
  }

  # THE assertion in this module. Overlapping ranges are accepted by AWS at
  # creation — nothing rejects them — and surface much later as traffic
  # arriving at the wrong subnet, which reads as a routing fault.
  assert {
    condition     = length(distinct([for s in aws_subnet.this : s.cidr_block])) == length(aws_subnet.this)
    error_message = "Two subnets were given the same range. AWS accepts that at creation and it surfaces later as traffic arriving in the wrong place."
  }

  # /20 split three ways takes two extra bits, so each zone gets a /22 and
  # a fourth block is left spare. That spare is the point: adding a zone
  # later must not renumber the existing three.
  assert {
    condition = alltrue([
      for k, s in aws_subnet.this : endswith(s.cidr_block, "/22") if startswith(k, "workload-")
    ])
    error_message = "A /20 divided across three zones should give each a /22, leaving a fourth block for a zone added later."
  }
}

run "no_subnet_hands_out_a_public_address" {
  command = plan

  variables {
    zones = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
  }

  # The AWS equivalent of an external IP on a GCP instance: a route to the
  # internet that does not pass the proxy and appears in no route table a
  # reviewer reads. Including on the load balancer subnets — the load
  # balancer gets its address from its own configuration, not from the
  # subnet handing one to everything launched there.
  assert {
    condition     = alltrue([for s in aws_subnet.this : s.map_public_ip_on_launch == false])
    error_message = "A subnet that auto-assigns public addresses is a path out that bypasses the proxy entirely."
  }
}

run "eks_can_only_place_a_public_load_balancer_in_the_lb_subnets" {
  command = plan

  # EKS discovers subnets by tag. Tagging everything with role/elb would
  # let an internet-facing load balancer be created in the workload subnet
  # — which is how a private cluster acquires a public entry point without
  # anyone editing a route or a firewall rule.
  assert {
    condition = alltrue([
      for k, s in aws_subnet.this :
      contains(keys(s.tags), "kubernetes.io/role/elb") if startswith(k, "lb-")
    ])
    error_message = "The load balancer subnets must carry role/elb or a Service of type LoadBalancer fails to place."
  }

  assert {
    condition = alltrue([
      for k, s in aws_subnet.this :
      !contains(keys(s.tags), "kubernetes.io/role/elb") if !startswith(k, "lb-")
    ])
    error_message = "Only the load balancer subnets may carry role/elb, or an internet-facing load balancer can be placed among the workloads."
  }
}

run "duplicate_zones_are_refused" {
  command = plan

  variables {
    zones = ["eu-west-3a", "eu-west-3a"]
  }

  # Two subnets with different ranges in the same place, quietly halving
  # the addresses available to each.
  expect_failures = [var.zones]
}

run "two_workload_subnets_are_refused" {
  command = plan

  variables {
    subnets = {
      workload = { cidr = "10.10.0.0/20", purpose = "workload" }
      other    = { cidr = "10.10.32.0/20", purpose = "workload" }
    }
  }

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
  # value matches no branch there, so the subnet silently gets no rules and
  # no route — which reads as "isolated by design" rather than as a typo.
  expect_failures = [var.subnets]
}

run "purpose_groups_are_what_downstream_units_consume" {
  command = plan

  variables {
    zones = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
  }

  # The cluster and NAT units care that a subnet is a workload or proxy
  # subnet, never which zone it is in. Asking them to reconstruct that from
  # key names would put the naming convention into three more modules.
  assert {
    condition     = length(output.ids_by_purpose["workload"]) == 3
    error_message = "Every zone's workload subnet must appear in the workload group."
  }

  assert {
    condition     = length(output.ids_by_purpose["public-lb"]) == 3
    error_message = "Every zone's load balancer subnet must appear in the public-lb group."
  }
}
