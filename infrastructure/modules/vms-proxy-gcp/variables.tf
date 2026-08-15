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

variable "network_id" {
  type        = string
  description = "The VPC, from services/network/vpc."
}

variable "subnetwork" {
  type        = string
  description = "The egress subnet these instances sit in — the only one with a way out."
}

variable "zones" {
  type        = list(string)
  description = "Zones the fleet is spread across. One in staging, three in production."

  validation {
    condition     = length(var.zones) > 0
    error_message = "At least one zone is required."
  }
}

variable "ha" {
  type        = bool
  default     = false
  description = <<-EOT
    Run more than one instance.

    Not about load — one instance serves the traffic — but about a restart
    or a zone failure not being an outage for everything behind the proxy,
    which in this design is everything.
  EOT
}

variable "ha_size" {
  type        = number
  default     = 2
  description = "Fleet size when ha is on."

  validation {
    condition     = var.ha_size >= 2
    error_message = "An HA fleet of one is not one."
  }
}

variable "port" {
  type        = number
  default     = 3128
  description = "The port Squid listens on. Must match the firewall rule and the route, all three of which read it from the same config key."
}

variable "proxy_tag" {
  type        = string
  default     = "egress-proxy"
  description = <<-EOT
    Network tag placed on these instances.

    It is a capability, not a label: services/network/routes and
    services/network/firewall both key on it, so carrying it is what grants
    an instance the internet.
  EOT
}

variable "client_cidrs" {
  type        = list(string)
  description = <<-EOT
    Ranges permitted to use the proxy — the workload subnets.

    The firewall says the same thing at the packet layer. Saying it twice
    is deliberate: a mistake in either one is then not enough on its own to
    open the path.
  EOT

  validation {
    condition     = length(var.client_cidrs) > 0
    error_message = "With no client ranges the proxy denies everyone, and the workloads fail with connection refused rather than with a policy message."
  }

  validation {
    condition     = !contains(var.client_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 as a client range makes the proxy an open relay for anything that can reach it."
  }
}

variable "allowed_domains" {
  type        = list(string)
  description = <<-EOT
    Destinations the proxy will forward to. THE POLICY.

    No default, deliberately. A permissive one would make this fleet a
    router with extra steps — satisfying "traffic leaves through one place"
    while giving up the reason that was worth arranging. Naming what the
    estate is allowed to reach is the point of having a proxy at all.

    Domains rather than addresses: an address list rots silently as
    services move, and the failure is a timeout with nothing to say a
    policy caused it.
  EOT

  validation {
    condition     = length(var.allowed_domains) > 0
    error_message = "An empty allow-list denies everything, which is safe and useless."
  }

  validation {
    condition     = !contains(var.allowed_domains, ".")
    error_message = "\".\" matches every domain and turns the allow-list into an allow-all."
  }
}

variable "machine_type" {
  type        = string
  default     = "e2-small"
  description = "Instance size. A proxy is network-bound rather than CPU-bound; the smallest sizes are usually enough and the fleet scales by count."
}

variable "image" {
  type        = string
  default     = "debian-cloud/debian-12"
  description = "Boot image. Debian because the startup script installs squid from apt."
}

variable "disk_size_gb" {
  type        = number
  default     = 20
  description = "Boot disk. Nothing is cached, so this holds the system and the logs until they ship."
}
