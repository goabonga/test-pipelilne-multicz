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
  description = "The VPC the router belongs to, from services/network/vpc."
}

variable "subnetworks" {
  type        = list(string)
  description = <<-EOT
    Self links of the subnets this NAT translates for — the EGRESS subnets,
    and nothing else.

    Cloud NAT's default is ALL_SUBNETWORKS_ALL_IP_RANGES. Taking it would
    give the workload subnet a path to the internet that bypasses the
    proxy, needs no route, appears in no firewall rule, and works.
  EOT

  validation {
    condition     = length(var.subnetworks) > 0
    error_message = "A NAT that translates for no subnet does nothing and still costs money."
  }
}

variable "nat_ips" {
  type        = list(string)
  description = <<-EOT
    Reserved addresses from services/network/addresses/public.

    Passed explicitly because the alternative — letting Cloud NAT allocate
    its own — works perfectly and changes the egress address whenever the
    NAT is recreated, breaking every external allow-list while the reserved
    addresses sit unused and billed.
  EOT
}

variable "min_ports_per_vm" {
  type        = number
  default     = 128
  description = <<-EOT
    Ports held per VM, used or not.

    The capacity limit that bites first: each address gives roughly 64k
    ports, so a generous number with a small pool exhausts the pool on idle
    reservations. The symptom is new connections failing while existing
    ones are fine.
  EOT

  validation {
    condition     = var.min_ports_per_vm >= 64 && var.min_ports_per_vm <= 65536
    error_message = "min_ports_per_vm must be between 64 and 65536."
  }
}

variable "dynamic_port_allocation" {
  type        = bool
  default     = true
  description = "Let Cloud NAT grow a VM's port allocation on demand up to max_ports_per_vm, rather than reserving the maximum up front."
}

variable "max_ports_per_vm" {
  type        = number
  default     = 8192
  description = "Ceiling when dynamic allocation is on. Ignored otherwise."
}

variable "logging_enabled" {
  type        = bool
  default     = true
  description = "Log NAT events. A dropped translation is what explains an outage nobody can otherwise account for."
}

variable "log_filter" {
  type        = string
  default     = "ERRORS_ONLY"
  description = <<-EOT
    ERRORS_ONLY, TRANSLATIONS_ONLY or ALL.

    Errors by default: logging every translation on a busy proxy fleet
    produces volume nobody reads and a bill somebody notices, while the
    dropped ones are the events that explain a failure.
  EOT

  validation {
    condition     = contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], var.log_filter)
    error_message = "log_filter must be ERRORS_ONLY, TRANSLATIONS_ONLY or ALL."
  }
}
