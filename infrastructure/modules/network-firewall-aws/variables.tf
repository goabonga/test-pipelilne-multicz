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
  description = "The VPC these groups belong to, from services/network/vpc."
}

variable "workload_subnet_ids" {
  type        = list(string)
  default     = []
  description = "Subnets the interface endpoints put an ENI in. One per zone, so a zone failure does not take the API with it."
}

variable "workload_route_table_ids" {
  type        = list(string)
  default     = []
  description = <<-EOT
    Route tables the S3 gateway endpoint attaches to — the workload ones,
    which have no default route.

    Without it a node cannot reach S3 at all, and ECR stores every image
    layer there, so the symptom is an image pull that fails partway with a
    network error rather than an access one.
  EOT
}

variable "proxy_port" {
  type        = number
  default     = 3128
  description = "The port Squid listens on. The workload may reach the proxy on this port and no other."
}

variable "proxy_egress_ports" {
  type        = list(number)
  default     = [80, 443]
  description = <<-EOT
    What the proxies themselves may reach on the internet.

    Deliberately not "all": a proxy that can open any port is a tunnel out
    for anything that reaches it, which is most of the estate.
  EOT
}

variable "node_port_range" {
  type        = list(number)
  default     = [30000, 32767]
  description = "Kubernetes NodePort range, the ports the load balancer reaches on a node."

  validation {
    condition     = length(var.node_port_range) == 2 && var.node_port_range[0] < var.node_port_range[1]
    error_message = "node_port_range must be [from, to] with from below to."
  }
}

variable "lb_ingress_cidrs" {
  type        = list(string)
  default     = []
  description = <<-EOT
    Who may reach the load balancer.

    THE ONE PER-ENVIRONMENT DECISION IN THIS MODULE. Production is public
    and passes 0.0.0.0/0; staging passes its own ranges and gets an
    internal front end from the same code. Empty means the load balancer
    accepts nothing, which is the correct resting state before an
    environment has decided.
  EOT

  validation {
    condition     = alltrue([for c in var.lb_ingress_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry must be valid CIDR notation."
  }
}

variable "interface_endpoints" {
  type        = list(string)
  default     = null
  description = <<-EOT
    AWS services reachable over private addresses. Null takes the default
    set: Session Manager, ECR, CloudWatch Logs and STS — the minimum for a
    node to be reachable, pull an image and say anything about itself.

    Each costs an hourly charge per zone, which is the usual reason someone
    removes one and reaches for a NAT instead.
  EOT
}

variable "s3_endpoint_enabled" {
  type        = bool
  default     = true
  description = "Attach the S3 gateway endpoint. It is free, and ECR image layers live in S3."
}
