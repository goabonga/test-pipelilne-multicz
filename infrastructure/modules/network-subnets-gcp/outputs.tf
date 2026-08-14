# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "ids" {
  value       = { for k, s in google_compute_subnetwork.this : k => s.id }
  description = "Subnet ids keyed by the short name from the config."
}

output "self_links" {
  value       = { for k, s in google_compute_subnetwork.this : k => s.self_link }
  description = "Subnet self links keyed by short name. What the nodes and NAT units attach to."
}

output "cidrs" {
  value       = { for k, s in google_compute_subnetwork.this : k => s.ip_cidr_range }
  description = "The ranges that were actually created. Firewall rules are written against these rather than against the config, so a rule cannot outlive the subnet it names."
}

output "workload_subnet" {
  value       = one([for k, v in var.subnets : k if v.purpose == "workload"])
  description = "Short name of the subnet pods run in. The cluster unit needs to know which one that is."
}

output "secondary_range_names" {
  value = {
    pods     = "${var.name}-pods"
    services = "${var.name}-services"
  }
  description = "Names GKE refers to the secondary ranges by. Wrong names fail cluster creation with an unhelpful 'range not found'."
}
