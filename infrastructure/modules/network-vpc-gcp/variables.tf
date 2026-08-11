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

variable "routing_mode" {
  type        = string
  default     = "REGIONAL"
  description = <<-EOT
    REGIONAL or GLOBAL. Regional keeps Cloud Router advertisements inside
    the region, which is what a single-region deployment wants; GLOBAL is
    for a network spanning regions and costs cross-region traffic.
  EOT

  validation {
    condition     = contains(["REGIONAL", "GLOBAL"], var.routing_mode)
    error_message = "routing_mode must be REGIONAL or GLOBAL."
  }
}

variable "delete_default_routes" {
  type        = bool
  default     = true
  description = <<-EOT
    Remove the 0.0.0.0/0 route to the internet gateway at creation.

    True is the design: workloads leave only through the egress proxy, and
    services/network/routes installs the routes that are actually wanted.
  EOT
}

variable "allow_default_internet_route" {
  type        = bool
  default     = false
  description = <<-EOT
    Acknowledge that keeping the default route is intended. Only read when
    delete_default_routes is false — it exists so that turning the guard
    off is a deliberate second act rather than a single flag flip.
  EOT
}
