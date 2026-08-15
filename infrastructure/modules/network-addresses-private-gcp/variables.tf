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

variable "subnetwork" {
  type        = string
  description = "The proxy subnet this address is taken from, from services/network/subnets."
}

variable "subnet_cidr" {
  type        = string
  description = <<-EOT
    The proxy subnet's range, used only to check the address against.

    Without it a typo lands outside the subnet and fails at apply — after
    everything before it in the run has already applied.
  EOT

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be valid CIDR notation."
  }
}

variable "address_index" {
  type        = number
  default     = 10
  description = <<-EOT
    Which address in the proxy subnet to reserve, counting from the
    network address.

    An index rather than an address: both services/network/routes and
    services/vms/proxy need to agree on this value without depending on
    each other, so it has to be written down — and a written-down address
    can land outside the subnet, which fails at apply after everything
    before it has already applied. An index cannot.

    Four is the lowest usable value; below that are the network address,
    the gateway, and two Google reserves.
  EOT

  validation {
    condition     = var.address_index >= 4
    error_message = "Indices below 4 are reserved by GCP."
  }
}
