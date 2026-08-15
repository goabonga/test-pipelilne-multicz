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
  description = "The VPC these rules apply to, from services/network/vpc."
}

variable "proxy_tag" {
  type        = string
  default     = "egress-proxy"
  description = "Network tag on the egress proxies. Carrying it is what permits reaching the internet, so it belongs on the proxy fleet and nothing else."
}

variable "workload_tag" {
  type        = string
  default     = "workload"
  description = "Network tag on the nodes pods run on. Carrying it permits reaching the proxy, and nothing beyond it."
}

variable "proxy_subnet_cidr" {
  type        = string
  description = <<-EOT
    The proxy subnet's range — the workload's only permitted destination
    outside its own subnet.

    Written against the range rather than a tag on purpose: an egress rule
    to a target tag would let a workload reach anything that later acquires
    that tag, wherever it sits.
  EOT

  validation {
    condition     = can(cidrhost(var.proxy_subnet_cidr, 0))
    error_message = "proxy_subnet_cidr must be valid CIDR notation."
  }
}

variable "proxy_port" {
  type        = number
  default     = 3128
  description = "The port Squid listens on. The workload may reach the proxy subnet on this port and no other."
}

variable "proxy_egress_ports" {
  type        = list(string)
  default     = ["80", "443"]
  description = <<-EOT
    What the proxies themselves may reach on the internet.

    Deliberately not "all": a proxy that can open any port is a tunnel out
    for anything that reaches it, which is most of the estate. Widen this
    when something genuinely needs another protocol, and know what.
  EOT
}

variable "google_apis_cidr" {
  type        = string
  default     = "199.36.153.8/30"
  description = "Google's private API range. Must match the route in services/network/routes — the route makes it reachable, this makes it permitted, and both are required."
}

variable "internal_ranges" {
  type        = list(string)
  description = <<-EOT
    Ranges treated as inside: the VPC, the pod range and the service range.

    A cluster whose nodes cannot reach each other does not form, and the
    failure presents as a control plane problem rather than as a firewall
    one.
  EOT

  validation {
    condition     = length(var.internal_ranges) > 0
    error_message = "At least the VPC range is required, or no node can reach another."
  }

  validation {
    condition     = !contains(var.internal_ranges, "0.0.0.0/0")
    error_message = "0.0.0.0/0 is not internal. Listing it here permits every outbound connection and silently undoes the deny this module is built around."
  }
}

variable "tunnel_ingress_enabled" {
  type        = bool
  default     = true
  description = "Allow the control-plane tunnel in. Off leaves no inbound path to any instance at all, including for an operator."
}

variable "logging_enabled" {
  type        = bool
  default     = true
  description = <<-EOT
    Log denied egress and tunnel connections.

    The denies are the point: a refused outbound connection is the signal
    that something is trying to leave another way, and this is the only
    place that attempt is recorded.
  EOT
}
