# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The VPC every other unit hangs off.
#
# Custom mode, not auto mode: subnets are their own unit
# (services/network/subnets), so the network must not create a subnet per
# region behind its back. Auto mode also hands out 10.128.0.0/9, which
# would collide with the environment CIDR plan.

resource "google_compute_network" "this" {
  # checkov:skip=CKV2_GCP_18: The firewall is a separate unit
  # (services/network/firewall -> modules/network-firewall-gcp), which
  # depends on this one, so checkov cannot see it from here — the rule
  # looks for firewall resources in the same module.
  #
  # The caveat is real and worth stating: nothing in THIS module forces
  # that unit to exist. An environment whose config sets
  # services.network.firewall.enabled = false gets a network with no rules
  # beyond GCP's implied deny-ingress / allow-egress, and the egress half
  # of that is exactly what the removed default route is meant to close.
  # The two belong together; splitting them is a layout choice, not a
  # weakening, only as long as both are enabled.
  name                    = var.name
  project                 = var.project
  auto_create_subnetworks = false
  routing_mode            = var.routing_mode
  description             = "Shomer ${var.environment} — managed by terragrunt"

  # THE DEFAULT ROUTE IS REMOVED AT CREATION.
  #
  # A fresh VPC ships a 0.0.0.0/0 route to the internet gateway. Leaving it
  # means any instance with an external IP, or any subnet behind a NAT,
  # reaches the internet directly — and the whole point of this design is
  # that workloads leave only through the Squid proxy.
  #
  # Removing it later is not equivalent: between creation and the fix there
  # is a window where egress is open, and `terraform destroy` on the route
  # would fight the API, which recreates it.
  #
  # services/network/routes puts back exactly the routes that are wanted,
  # including the one that sends 0.0.0.0/0 to the proxy's internal load
  # balancer. Until it runs, this network has no path out. That is the
  # intended resting state, not an outage.
  delete_default_routes_on_create = var.delete_default_routes

  lifecycle {
    precondition {
      condition     = var.delete_default_routes || var.allow_default_internet_route
      error_message = "Keeping the default 0.0.0.0/0 route bypasses the egress proxy. Set allow_default_internet_route = true to say that is intended."
    }
  }
}
