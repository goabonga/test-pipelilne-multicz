# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The proxy load balancer's private addresses — decided here, claimed
# elsewhere.
#
# THIS MODULE CREATES NOTHING, AND THAT IS THE HONEST SHAPE OF IT.
#
# AWS has no reservation for a private address the way GCP does: an
# internal load balancer takes a specific address at attach time through
# subnet_mapping, or is handed one. So there is nothing to reserve, and
# pretending otherwise would mean creating an ENI to hold an address that
# the load balancer then could not use.
#
# What it does have is the same JOB as its GCP counterpart: decide the
# address, so that services/vms/proxy and anything pointing at the proxy
# agree on it without either depending on the other. On GCP that agreement
# lets the workload's route exist before the proxy does. Here the workload
# has no route at all — it reaches the proxy by explicit configuration —
# and the agreement is what lets that configuration be written before the
# load balancer is built.
#
# One address per zone, because a network load balancer takes one per
# subnet it is placed in.

locals {
  # Derived rather than written out. An address typed by hand can land
  # outside its subnet, and that failure arrives at apply — after
  # everything before it in the run has already applied.
  addresses = {
    for zone, cidr in var.subnet_cidrs :
    zone => cidrhost(cidr, var.address_index)
  }
}

# A single terraform_data to give the module a node in the graph and a
# place to state the constraint. Without it the preconditions below would
# have nowhere to live, and a module that only computes locals cannot fail
# a plan — which would make the checks decorative.
resource "terraform_data" "addresses" {
  input = local.addresses

  lifecycle {
    precondition {
      # The first four addresses of an AWS subnet are reserved — network,
      # VPC router, DNS, and one AWS holds back — plus the broadcast
      # address at the end. Asking for one fails at attach time with a
      # message about the address being unavailable, which reads as a
      # collision with something somebody else created.
      condition     = var.address_index >= 4
      error_message = "The first four addresses in an AWS subnet are reserved: network, router, DNS, and one AWS holds back. Pick an index of 4 or more."
    }

    precondition {
      condition     = length(var.subnet_cidrs) > 0
      error_message = "No subnets: there is no address to decide, and the proxy's configuration would have nothing to point at."
    }
  }
}
