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
    error_message = "Give the domain without a trailing dot; the module adds it where the API needs one."
  }
}

variable "dnssec" {
  type        = bool
  default     = true
  description = <<-EOT
    Sign the zone.

    On by default: this zone serves the one public entry point to an
    otherwise private estate, which makes it worth being unable to forge.
    Turning it off is a decision about a specific registrar limitation, not
    a default to inherit.
  EOT
}

variable "records" {
  type = map(object({
    type   = string
    ttl    = optional(number, 300)
    values = list(string)
  }))
  default     = {}
  description = <<-EOT
    Records in the zone, keyed by name relative to the domain.

    Only the load balancer belongs here. Everything else in this
    infrastructure is private and must not appear in a zone the internet
    reads.
  EOT

  validation {
    condition = alltrue([
      for k, r in var.records : alltrue([
        for v in r.values :
        r.type != "A" || !can(regex("^(10\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.)", v))
      ])
    ])
    error_message = "A public zone must not publish RFC1918 addresses. The name would not resolve usefully for anyone outside the network, and it tells the world the shape of one that is meant to be private."
  }

  validation {
    condition = alltrue([
      for k, r in var.records : contains(["A", "AAAA", "CNAME", "TXT", "MX", "CAA", "NS", "SRV"], r.type)
    ])
    error_message = "Unrecognised record type."
  }
}
