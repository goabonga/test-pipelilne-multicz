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

variable "network_id" {
  type        = string
  description = "The VPC these subnets belong to, from services/network/vpc."
}

variable "subnets" {
  type = map(object({
    cidr    = string
    purpose = string
  }))
  description = <<-EOT
    The subnets to create, keyed by short name, straight from
    `network.subnets` in the environment config.

    `purpose` is behaviour, not documentation: "workload" is the one that
    receives the pod and service ranges, and the routes unit reads the same
    key to decide which subnets get a way out.
  EOT

  validation {
    condition     = alltrue([for k, v in var.subnets : contains(["workload", "egress", "public-lb"], v.purpose)])
    error_message = "purpose must be one of workload, egress, public-lb — the routes and firewall units branch on these exact values."
  }

  validation {
    condition     = alltrue([for k, v in var.subnets : can(cidrhost(v.cidr, 0))])
    error_message = "Every subnet needs a valid CIDR."
  }

  validation {
    # Checked on the input rather than as a resource precondition: the
    # outputs also assume exactly one, and `one()` fails first with
    # "Invalid value for list parameter", which says nothing about what is
    # actually wrong.
    condition     = length([for k, v in var.subnets : k if v.purpose == "workload"]) == 1
    error_message = "Exactly one subnet must have purpose = \"workload\": GKE takes its pod and service ranges from that one subnet, and a second would create another place pods could be scheduled, outside the firewall rules written for the first."
  }
}

variable "pods_cidr" {
  type        = string
  description = <<-EOT
    Secondary range for pod addresses, attached to the workload subnet.

    It has to be large enough for every pod that will ever run: GKE cannot
    grow it after the cluster is created, and the failure mode is a node
    pool that will not scale with no obvious reason why.
  EOT

  validation {
    condition     = can(cidrhost(var.pods_cidr, 0))
    error_message = "pods_cidr must be valid CIDR notation."
  }
}

variable "services_cidr" {
  type        = string
  description = "Secondary range for ClusterIP services, attached to the workload subnet."

  validation {
    condition     = can(cidrhost(var.services_cidr, 0))
    error_message = "services_cidr must be valid CIDR notation."
  }
}

variable "flow_logs_enabled" {
  type        = bool
  default     = true
  description = "Record traffic per subnet. The only evidence that something tried to leave another way."
}

variable "flow_logs_sampling" {
  type        = number
  default     = 0.5
  description = <<-EOT
    Fraction of flows recorded, 0 to 1. Half rather than all: the full rate
    on a busy subnet costs more than the incidents it catches, and half
    still shows a pattern of attempts.
  EOT

  validation {
    condition     = var.flow_logs_sampling > 0 && var.flow_logs_sampling <= 1
    error_message = "flow_logs_sampling must be greater than 0 and at most 1. Zero would create a log config that records nothing."
  }
}
