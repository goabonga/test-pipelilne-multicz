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

variable "domain" {
  type        = string
  description = "The zone's domain, without a trailing dot."

  validation {
    condition     = !endswith(var.domain, ".")
    error_message = "Give the domain without a trailing dot."
  }
}

variable "vpc_ids" {
  type        = list(string)
  description = <<-EOT
    VPCs this zone resolves in.

    THE mechanism, not a convenience: a private zone with no VPC resolves
    for nobody and creates cleanly while doing so.
  EOT

  validation {
    condition     = length(var.vpc_ids) > 0
    error_message = "At least one VPC is required, or the zone resolves for nobody."
  }
}

variable "records" {
  type = map(object({
    type   = string
    ttl    = optional(number, 300)
    values = list(string)
  }))
  default     = {}
  description = "Records in the zone, keyed by name relative to the domain."
}
