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

variable "public_subnet_ids" {
  type        = map(string)
  description = <<-EOT
    The subnet each zone's NAT gateway sits in, keyed by zone — the PUBLIC
    subnets, which are the ones with a route to the internet gateway.

    Not the proxy subnets, which is the intuitive answer and the wrong one:
    a gateway placed there has no way out, and the failure presents as a
    routing problem in the workloads behind it.
  EOT

  validation {
    condition     = length(var.public_subnet_ids) > 0
    error_message = "At least one zone needs a NAT gateway, or nothing behind the proxy can reach anything."
  }
}

variable "allocation_ids" {
  type        = map(string)
  description = <<-EOT
    Reserved elastic address per zone, from
    services/network/addresses/public.

    Passed explicitly rather than letting the gateway allocate its own: an
    automatic address changes whenever the gateway is recreated, which
    breaks every external allow-list while the reserved ones sit unused and
    billed.
  EOT
}
