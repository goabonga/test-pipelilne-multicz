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

variable "cidr" {
  type        = string
  description = <<-EOT
    The VPC's address range, from `network.cidr` in the environment config.

    It has to hold every subnet, the pod range and the service range, and
    it cannot be changed afterwards — resizing a VPC means rebuilding it.
  EOT

  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "cidr must be valid CIDR notation, e.g. 10.10.0.0/16."
  }

  validation {
    # /16 gives room for the subnets and the secondary ranges; anything
    # smaller than /20 cannot hold the layout in configs/<env>/config.yaml.
    condition     = tonumber(split("/", var.cidr)[1]) <= 20
    error_message = "cidr must be /20 or larger to hold the workload, proxy and lb subnets."
  }
}

variable "allow_public_cidr" {
  type        = bool
  default     = false
  description = <<-EOT
    Permit a VPC CIDR outside RFC1918. Off, because everything in this
    design is private and a public range would become routable the moment
    a gateway appeared, with nothing downstream noticing.
  EOT
}

variable "flow_logs_enabled" {
  type        = bool
  default     = true
  description = <<-EOT
    Record traffic the VPC refused. In a network whose whole design is
    "nothing leaves except through the proxy", this is the only thing that
    can say whether something found another way.
  EOT
}

variable "flow_logs_traffic_type" {
  type        = string
  default     = "REJECT"
  description = <<-EOT
    ACCEPT, REJECT or ALL. REJECT by default: accepted traffic inside a
    private network is the normal case, and its volume is the usual reason
    flow logs get switched off entirely.
  EOT

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_logs_traffic_type)
    error_message = "flow_logs_traffic_type must be ACCEPT, REJECT or ALL."
  }
}

variable "flow_logs_retention_days" {
  type        = number
  default     = 365
  description = <<-EOT
    How long flow logs are kept.

    A year rather than the operationally comfortable ninety days. An
    intrusion is typically found months after it happened, and a ninety-day
    window means the evidence of how something got out has already expired
    by the time anyone goes looking — which is the one question flow logs
    exist to answer.
  EOT

  validation {
    condition     = var.flow_logs_retention_days > 0
    error_message = "Set a retention. Indefinite retention of flow logs is a cost and a liability, not a default."
  }
}

variable "flow_logs_kms_key_arn" {
  type        = string
  default     = null
  description = <<-EOT
    Customer-managed key for the log group. Null uses the CloudWatch
    service key, which still encrypts at rest but leaves the audit trail of
    who read the logs in AWS's hands rather than yours.
  EOT
}
