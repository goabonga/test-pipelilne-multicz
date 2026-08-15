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

variable "network_name" {
  type        = string
  description = "The VPC these routes belong to, from services/network/vpc."
}

variable "proxy_tag" {
  type        = string
  default     = "egress-proxy"
  description = <<-EOT
    Network tag identifying the egress proxies. The instances that carry it
    reach the internet directly; nothing else does.

    It is a capability, not a label. Adding it to an instance grants that
    instance unmediated internet access, so it belongs on the proxy fleet
    and on nothing else.
  EOT
}

variable "workload_tag" {
  type        = string
  default     = "workload"
  description = <<-EOT
    Network tag identifying the nodes pods run on. Instances carrying it
    reach the internet only through the proxy, and only once the proxy
    exists.
  EOT
}

variable "proxy_ilb_address" {
  type        = string
  default     = null
  description = <<-EOT
    Forwarding rule of the proxy's internal load balancer.

    Null until services/vms/proxy exists, and null means the workload nodes
    have NO default route at all — which is the intended resting state, not
    an outage. Pointing this at anything else in the meantime would open
    the path this design forbids, and it would work, which is why it would
    survive review.
  EOT
}

variable "google_apis_cidr" {
  type        = string
  default     = "199.36.153.8/30"
  description = <<-EOT
    Google's private API range. The default is private.googleapis.com,
    which serves most APIs over internal addresses.

    199.36.153.4/30 is restricted.googleapis.com, which serves only APIs
    that support VPC Service Controls and refuses the rest — stricter, and
    worth the swap where an exfiltration boundary is required.
  EOT

  validation {
    condition     = can(cidrhost(var.google_apis_cidr, 0))
    error_message = "google_apis_cidr must be valid CIDR notation."
  }
}
