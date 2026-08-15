# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The proxy's internal address, reserved before the proxy exists.
#
# THIS IS WHAT BREAKS THE ORDERING KNOT. The workload's default route has
# to point at the proxy's load balancer, and the load balancer is built by
# services/vms/proxy — so routes would have to wait for the proxy, and the
# proxy needs the firewall and the NAT, which are further down the same
# chain.
#
# Reserving the address here removes the dependency instead of ordering it.
# A GCP route's next_hop_ilb accepts an address, not only a forwarding
# rule, so services/network/routes can point at this the moment it exists —
# before anything is listening on it. Traffic sent there is dropped until
# the proxy comes up, which is the same state as having no route at all and
# arrives without a second apply.

resource "google_compute_address" "proxy_ilb" {
  name        = var.name
  project     = var.project
  region      = var.region
  description = "The proxy's internal load balancer address. Reserved here so the workload's route can exist before the proxy does."

  address_type = "INTERNAL"
  purpose      = "SHARED_LOADBALANCER_VIP"
  subnetwork   = var.subnetwork

  # DERIVED FROM THE SUBNET, not written out. An explicit address is what
  # lets routes and the proxy agree without depending on each other, but a
  # free-form string can land outside the subnet — and that fails at apply,
  # after everything before it in the run has already applied.
  #
  # An index into the subnet cannot. cidrhost does the arithmetic, and the
  # only way to be wrong is to be wrong about which subnet, which is the
  # same value the proxy is placed in.
  address = cidrhost(var.subnet_cidr, var.address_index)

  lifecycle {
    precondition {
      # The first four addresses of a GCP subnet are reserved — network,
      # gateway, and two Google keeps. Asking for one of them fails at
      # apply with a message about the address being in use, which reads as
      # a collision with something somebody else created.
      condition     = var.address_index >= 4
      error_message = "The first four addresses in a GCP subnet are reserved: network, gateway, and two Google holds back. Pick an index of 4 or more."
    }
  }
}
