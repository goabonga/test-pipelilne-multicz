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

variable "dnssec_key_arn" {
  type        = string
  default     = null
  description = <<-EOT
    Customer-managed KMS key that signs the zone. Null leaves it unsigned.

    Route 53 is a global service and signs only from us-east-1, so the key
    must live there whatever region the rest of the environment runs in —
    and the apply identity cannot create it, for the same reason it cannot
    create IAM roles. That is an ordering constraint, not a preference,
    which is why this is opt-in rather than defaulted on.
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

variable "query_log_group_arn" {
  type        = string
  default     = null
  description = <<-EOT
    CloudWatch log group receiving this zone's DNS queries. Null logs
    nothing.

    It must live in us-east-1 whatever region the rest of the environment
    runs in — Route 53 is global and writes query logs only from there —
    and it needs a resource policy the apply identity cannot create, which
    is why this is opt-in rather than defaulted on.

    Worth enabling once it exists: on a public zone the queries are the
    only record of who is probing names nobody advertised.
  EOT
}
