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

variable "subnet_cidrs" {
  type        = map(string)
  description = <<-EOT
    The proxy subnets' ranges, keyed by zone.

    A network load balancer takes one address per subnet it sits in, so
    there is one address per zone and each must come from that zone's own
    range.
  EOT

  validation {
    condition     = alltrue([for z, c in var.subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry must be valid CIDR notation."
  }
}

variable "address_index" {
  type        = number
  default     = 10
  description = <<-EOT
    Which address in each proxy subnet to claim, counting from the network
    address.

    An index rather than an address, for the same reason as the GCP module:
    the value has to be written down so two units can agree on it without
    depending on each other, and a written-down address can land outside
    its subnet — which fails at apply, after everything before it has
    already applied. An index cannot.

    Four is the lowest usable value; below it are the network address, the
    VPC router, the DNS server, and one AWS reserves.
  EOT

  validation {
    condition     = var.address_index >= 4
    error_message = "Indices below 4 are reserved by AWS."
  }
}
