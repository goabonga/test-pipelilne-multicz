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
  description = "The VPC these route tables belong to, from services/network/vpc."
}

variable "default_route_table_id" {
  type        = string
  description = <<-EOT
    The VPC's main route table, from services/network/vpc.

    Managed here so it can be emptied. Nothing should use it — every subnet
    is associated explicitly — but a subnet added later without an
    association inherits it silently, and inheriting nothing is a loud
    failure where inheriting a default route is not.
  EOT
}

variable "subnets" {
  type = map(object({
    id      = string
    purpose = string
    zone    = string
  }))
  description = <<-EOT
    The subnets to route, keyed as services/network/subnets emits them.

    `purpose` decides which table a subnet joins, and therefore whether it
    has a way out at all. An unrecognised value is refused rather than
    ignored: a subnet that matches no branch would get no association and
    fall back to the main table, which reads as "isolated" and is not.
  EOT

  validation {
    condition     = alltrue([for k, v in var.subnets : contains(["workload", "egress", "public-lb"], v.purpose)])
    error_message = "purpose must be one of workload, egress, public-lb."
  }
}

variable "nat_gateway_ids" {
  type        = map(string)
  default     = {}
  description = <<-EOT
    NAT gateway per zone, from services/network/nat. Empty until that unit
    exists, and empty means the proxies have no default route.

    That is the intended resting state, not an outage. Pointing this at the
    internet gateway in the meantime would give the proxy fleet unmediated
    egress and would work perfectly, which is why it would survive review.
  EOT
}
