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

variable "ip_count" {
  type        = number
  description = <<-EOT
    How many egress addresses to reserve, from `network.nat.ip_count`.

    It bounds concurrent outbound connections: each address gives roughly
    64k ports shared across everything behind the NAT. One is plenty until
    something starts opening thousands of connections to a single
    destination, at which point the symptom is intermittent connection
    failures under load rather than an obvious limit being hit.

    Growing this is safe — new addresses are added to the pool. SHRINKING
    IT IS NOT: it releases addresses that external services may have
    allow-listed, and the plan in the deploy PR is the only thing that will
    say so.
  EOT

  validation {
    condition     = var.ip_count >= 1
    error_message = "At least one egress address is required, or nothing behind the NAT can reach anything."
  }

  validation {
    condition     = var.ip_count <= 32
    error_message = "More than 32 egress addresses is almost certainly a typo rather than a capacity decision."
  }
}

variable "network_tier" {
  type        = string
  default     = "PREMIUM"
  description = <<-EOT
    PREMIUM or STANDARD.

    Premium by default: standard tier carries egress over the public
    internet from the region it leaves, which changes both the path and,
    for some destinations, the address geography an allow-list was written
    against.
  EOT

  validation {
    condition     = contains(["PREMIUM", "STANDARD"], var.network_tier)
    error_message = "network_tier must be PREMIUM or STANDARD."
  }
}
