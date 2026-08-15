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

variable "vpc_id" {
  type        = string
  description = "The VPC, from services/network/vpc."
}

variable "subnet_ids" {
  type        = list(string)
  description = "The egress subnets these instances sit in — the only ones with a way out."

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet is required."
  }
}

variable "security_group_id" {
  type        = string
  description = <<-EOT
    The proxy group from services/network/firewall.

    It is the capability: that group is the only one permitted to reach the
    internet, so membership is what grants this fleet egress.
  EOT
}

variable "instance_profile" {
  type        = string
  default     = null
  description = <<-EOT
    Instance profile for Session Manager access. Null leaves the fleet
    unreachable by an operator — which is a legitimate state, and not the
    one you want when the proxy is the thing that has failed.
  EOT
}

variable "ha" {
  type        = bool
  default     = false
  description = "Run more than one instance. Not about load — about a restart or a zone failure not being an outage for everything behind the proxy."
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
  description = "The port Squid listens on. Must match the security group rule, all of which read it from the same config key."
}

variable "client_cidrs" {
  type        = list(string)
  description = "Ranges permitted to use the proxy — the workload subnets. The security group says the same thing at the packet layer."

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
    Destinations the proxy will forward to. THE POLICY, and identical in
    shape to the GCP module so that one cloud cannot end up more permissive
    than the other by accident.
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

variable "instance_type" {
  type        = string
  default     = "t3.small"
  description = "A proxy is network-bound rather than CPU-bound; the fleet scales by count."
}

variable "image_id" {
  type        = string
  description = "AMI. Debian, because the user data installs squid from apt."
}

variable "disk_size_gb" {
  type        = number
  default     = 20
  description = "Root volume. Nothing is cached, so this holds the system and the logs until they ship."
}

variable "deletion_protection" {
  type        = bool
  default     = true
  description = <<-EOT
    Refuse to delete the load balancer.

    On by default: this one address is what every workload in the estate
    sends its traffic to, so deleting it is an outage for everything at
    once — and it is the kind of resource that gets caught up in a cleanup
    aimed at something else. Turn it off deliberately when tearing an
    environment down.
  EOT
}
