# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Address translation for the egress proxies, and for nothing else.
#
# WHICH SUBNETS THIS COVERS IS THE WHOLE DESIGN.
#
# Cloud NAT defaults to ALL_SUBNETWORKS_ALL_IP_RANGES. Accepting that
# default would give the workload subnet a way to the internet that does
# not pass the proxy, needs no route change, appears in no firewall rule,
# and works — which is to say it would undo services/network/routes and
# services/network/firewall at once, silently, from a single unrelated
# line.
#
# So the subnet list is explicit and the module refuses to include any
# subnet that is not an egress subnet.

resource "google_compute_router" "this" {
  name    = var.name
  project = var.project
  region  = var.region
  network = var.network_id

  description = "Carries the NAT configuration. No BGP, no peers — a router here is the object Cloud NAT hangs off, not a routing decision."
}

resource "google_compute_router_nat" "this" {
  name    = var.name
  project = var.project
  region  = var.region
  router  = google_compute_router.this.name

  # MANUAL_ONLY, and this is what makes the addresses unit mean anything.
  # AUTO_ONLY lets Cloud NAT allocate its own addresses, which works
  # perfectly and changes the egress address whenever the NAT is recreated
  # — quietly breaking every external allow-list, with the reserved
  # addresses still sitting there unused and billed.
  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips                = var.nat_ips

  # Never ALL_SUBNETWORKS_ALL_IP_RANGES. See the header.
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  dynamic "subnetwork" {
    for_each = var.subnetworks
    content {
      name                    = subnetwork.value
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }
  }

  # Ports are the capacity limit that bites first. Each address gives
  # roughly 64k of them; this is how many are held per VM whether or not it
  # uses them, so a large number with a small pool exhausts the pool with
  # idle reservations.
  min_ports_per_vm                    = var.min_ports_per_vm
  enable_dynamic_port_allocation      = var.dynamic_port_allocation
  max_ports_per_vm                    = var.dynamic_port_allocation ? var.max_ports_per_vm : null
  enable_endpoint_independent_mapping = false

  log_config {
    enable = var.logging_enabled
    # Errors only. Logging every translation on a busy proxy fleet produces
    # volume nobody reads and a bill somebody notices; a dropped
    # translation is the event that explains an outage.
    filter = var.log_filter
  }

  lifecycle {
    precondition {
      condition     = length(var.nat_ips) > 0
      error_message = "MANUAL_ONLY with no addresses leaves the proxies unable to reach anything. Reserve them in services/network/addresses/public first."
    }
  }
}
