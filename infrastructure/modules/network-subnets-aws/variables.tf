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

variable "vpc_id" {
  type        = string
  description = "The VPC these subnets belong to, from services/network/vpc."
}

variable "zones" {
  type        = list(string)
  description = <<-EOT
    Availability zones to spread across, from `zones` in the environment
    config. One in staging, three in production.

    Each purpose's range is divided evenly between them. The list order is
    part of the address assignment, so reordering it renumbers subnets and
    replaces them — append, never reorder.
  EOT

  validation {
    condition     = length(var.zones) > 0
    error_message = "At least one zone is required: an AWS subnet cannot exist outside one."
  }

  validation {
    condition     = length(var.zones) == length(distinct(var.zones))
    error_message = "Duplicate zones would put two subnets with different ranges in the same place and quietly halve the addresses available to each."
  }
}

variable "subnets" {
  type = map(object({
    cidr    = string
    purpose = string
  }))
  description = <<-EOT
    The subnets to create, keyed by short name, straight from
    `network.subnets` in the environment config. Each becomes one subnet
    per zone.

    `purpose` is behaviour, not documentation: the routes unit reads it to
    decide which subnets get a way out, and it decides which EKS load
    balancer tag each subnet carries.
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
    condition     = length([for k, v in var.subnets : k if v.purpose == "workload"]) == 1
    error_message = "Exactly one subnet must have purpose = \"workload\": a second would create another place pods could be scheduled, outside the firewall rules written for the first."
  }
}
