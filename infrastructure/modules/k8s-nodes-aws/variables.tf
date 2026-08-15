# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

variable "name" {
  description = "Name of the resource created by this module."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource this module creates."
  type        = map(string)
  default     = {}
}

# ── contract every unit in this stack passes ────────────────────────────
# Declared here rather than left to each implementation so the terragrunt
# `hcl validate --inputs --strict` cross-check has something to match, and
# so the gcp and aws implementations of a unit take the same inputs. A unit
# must not have to know which one it is talking to.

variable "environment" {
  type        = string
  description = "Environment name — staging or production. Used for naming and tagging, never for behaviour."
}

variable "region" {
  type        = string
  description = "Region the resources live in."
}

variable "project" {
  type        = string
  default     = null
  description = "GCP project. Null on AWS, where the account is implicit in the credentials."
}

variable "cluster_name" {
  type        = string
  description = "The cluster this group joins, from services/k8s/cluster."
}

variable "subnet_ids" {
  type        = list(string)
  description = <<-EOT
    Subnets the nodes sit in — THE WORKLOAD ONES, which have no default
    route.

    The load-bearing setting here. AWS has no tag-scoped route, so which
    subnet a node sits in is what decides whether its egress reaches the
    proxy or an internet gateway. A public subnet would work, be fast, and
    bypass the proxy entirely.
  EOT

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet is required."
  }
}

variable "node_role_arn" {
  type        = string
  description = <<-EOT
    IAM role the nodes assume.

    Created outside this module because the apply identity deliberately
    excludes IAM — granting the apply path role creation hands it a route
    to privilege escalation no plan reviewer would see.
  EOT
}

variable "ha" {
  type        = bool
  default     = false
  description = "Run the group across every workload subnet, with a higher floor. The difference between a zone failure costing capacity and costing the cluster."
}

variable "instance_types" {
  type        = list(string)
  default     = ["m6i.large"]
  description = "Node sizes. A list because a managed group falls back to the next type when the first is unavailable in a zone."
}

variable "capacity_type" {
  type        = string
  default     = "ON_DEMAND"
  description = <<-EOT
    ON_DEMAND or SPOT.

    Spot is materially cheaper and can be reclaimed with two minutes'
    notice. It is a reasonable choice for a stateless workload and a poor
    one for a cluster whose egress path is a single proxy fleet — losing
    several nodes at once is exactly when everything tries to reconnect.
  EOT

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "disk_size_gb" {
  type        = number
  default     = 100
  description = "Node volume. Holds the image layers, which is usually what fills it."
}

variable "min_nodes_ha" {
  type        = number
  default     = 3
  description = "Autoscaler floor when ha is on — one per zone for a three-zone production."
}

variable "max_nodes_ha" {
  type        = number
  default     = 15
  description = "Autoscaler ceiling when ha is on. The number that decides the worst-case bill."
}

variable "max_nodes" {
  type        = number
  default     = 3
  description = "Autoscaler ceiling without ha."
}

variable "node_labels" {
  type        = map(string)
  default     = {}
  description = "Kubernetes labels on every node in the group."
}

variable "metadata_hop_limit" {
  type        = number
  default     = 1
  description = <<-EOT
    How many network hops a metadata response may travel.

    One puts the metadata service out of reach of every pod — a packet from
    a pod's namespace has already taken a hop — while leaving it reachable
    by the kubelet, which runs in the host namespace at zero hops.

    Two is the value usually copied around, and it makes requiring IMDSv2
    only half a control: a pod can still ask, it just has to ask correctly.
    Raise it only for a workload that genuinely needs host-level metadata,
    knowing it then applies to every pod on the node.
  EOT

  validation {
    condition     = var.metadata_hop_limit >= 1 && var.metadata_hop_limit <= 2
    error_message = "metadata_hop_limit must be 1 or 2. Anything higher reaches through several layers of container networking."
  }
}
