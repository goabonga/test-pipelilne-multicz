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

variable "zones" {
  type        = list(string)
  description = <<-EOT
    Zones to place an egress address in, one each.

    This is the pool size on AWS. A NAT gateway accepts exactly one
    address, so the number of zones IS the number of addresses, and adding
    a zone is how the pool grows.
  EOT

  validation {
    condition     = length(var.zones) > 0
    error_message = "At least one zone is required, or there is no egress address at all."
  }

  validation {
    condition     = length(var.zones) == length(distinct(var.zones))
    error_message = "Duplicate zones would allocate two addresses for one NAT gateway, one of which is billed and attached to nothing."
  }
}

variable "ip_count" {
  type        = number
  default     = 1
  description = <<-EOT
    The number of egress addresses the environment config asks for.

    Not used to allocate — the zone list decides that — but checked against
    it, so a config asking for four addresses in a single-zone environment
    fails here rather than quietly receiving one. That mismatch is the kind
    of thing discovered under load, months later.
  EOT

  validation {
    condition     = var.ip_count >= 1
    error_message = "At least one egress address is required."
  }
}
