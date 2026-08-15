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
  description = "The cluster this pool joins, from services/k8s/cluster."
}

variable "zones" {
  type        = list(string)
  description = "Zones available to this pool. All of them when ha is on, the first otherwise."

  validation {
    condition     = length(var.zones) > 0
    error_message = "At least one zone is required."
  }
}

variable "ha" {
  type        = bool
  default     = false
  description = "Spread the pool across every zone. The difference between a zone failure costing capacity and costing the cluster."
}

variable "workload_tag" {
  type        = string
  default     = "workload"
  description = <<-EOT
    Network tag placed on every node.

    THE load-bearing setting in this module. services/network/routes and
    services/network/firewall both key on it: it is what sends these nodes'
    egress to the proxy and what permits them to reach it. Without it a
    pool builds, joins, runs pods and can reach nothing outside the VPC,
    with no error anywhere that says why.
  EOT
}

variable "machine_type" {
  type        = string
  default     = "e2-standard-4"
  description = "Node size."
}

variable "disk_size_gb" {
  type        = number
  default     = 100
  description = "Node boot disk. Holds the image layers, which is usually what fills it."
}

variable "min_nodes_ha" {
  type        = number
  default     = 1
  description = "Autoscaler floor per zone when ha is on. Per ZONE — a three-zone production runs three times this."
}

variable "max_nodes_ha" {
  type        = number
  default     = 5
  description = "Autoscaler ceiling per zone when ha is on. Per ZONE, and therefore the number that decides the worst-case bill."
}

variable "max_nodes" {
  type        = number
  default     = 3
  description = "Autoscaler ceiling without ha."
}

variable "node_roles" {
  type = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/artifactregistry.reader",
  ]
  description = <<-EOT
    Project roles for the node identity: write logs, write metrics, pull
    images. Nothing else.

    The default compute service account carries project editor in most
    projects, and anything that reads the node's token inherits whatever it
    holds — which is why this account exists rather than borrowing that one.
  EOT

  validation {
    condition     = !contains(var.node_roles, "roles/editor") && !contains(var.node_roles, "roles/owner")
    error_message = "editor or owner on the node identity means every pod that can read the node's token can change the project."
  }
}
