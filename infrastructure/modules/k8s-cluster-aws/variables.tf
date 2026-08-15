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

variable "subnet_ids" {
  type        = list(string)
  description = <<-EOT
    Subnets the control plane's network interfaces live in — the workload
    subnets, which are private.

    EKS requires at least two availability zones for the control plane even
    when the workloads run in one, which is why a single-zone staging still
    needs two entries here.
  EOT

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS needs at least two subnets, in different zones."
  }
}

variable "security_group_id" {
  type        = string
  description = "The workload group from services/network/firewall."
}

variable "cluster_role_arn" {
  type        = string
  description = <<-EOT
    IAM role the control plane assumes.

    Created outside this module because the apply identity deliberately
    excludes IAM — see infrastructure/bootstrap/README.md. Granting the
    apply path the ability to create roles hands it a route to privilege
    escalation that no reviewer of a Terraform plan would see.
  EOT
}

variable "kubernetes_version" {
  type        = string
  description = "Control plane version. Pinned rather than defaulted: an unpinned cluster upgrades on AWS's schedule rather than on a reviewed change."
}

variable "service_cidr" {
  type        = string
  description = <<-EOT
    Range for ClusterIP services. Must not overlap the VPC — it is a
    virtual range inside the cluster, and an overlap makes some VPC address
    permanently unreachable from a pod, which presents as one service
    failing for no visible reason.
  EOT

  validation {
    condition     = can(cidrhost(var.service_cidr, 0))
    error_message = "service_cidr must be valid CIDR notation."
  }
}

variable "enabled_log_types" {
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  description = <<-EOT
    Control plane logs. All five by default.

    api and audit are the two that answer "who did this?"; without them the
    question has no answer, and it is always asked after the fact. The
    other three answer "why did the cluster do that?" — a pod that never
    schedules or a controller that keeps retrying leaves its only trace
    there.

    Dropping some is a cost decision. Make it deliberately, knowing which
    question stops being answerable.
  EOT

  validation {
    condition     = contains(var.enabled_log_types, "audit")
    error_message = "The audit log is the record of who changed what. A cluster without it cannot answer the question it will be asked."
  }
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "Key for envelope-encrypting Kubernetes secrets. Null leaves them encrypted with AWS's own key, which is true and says nothing about who can read them."
}

variable "allow_self_managed_addons" {
  type        = bool
  default     = false
  description = <<-EOT
    Kept as a documented false rather than removed, because the temptation
    to flip it is real and the reason not to belongs where someone would
    look.

    Letting EKS install the VPC CNI and kube-proxy and deleting them
    afterwards leaves a window in which pods get the wrong datapath and no
    policy is enforced by anything — and nodes that join during it keep the
    old datapath until replaced. A cluster with no CNI is NotReady, which
    is loud; a cluster enforcing nothing looks healthy.
  EOT

  validation {
    condition     = var.allow_self_managed_addons == false
    error_message = "Self-managed addons would install the VPC CNI and kube-proxy alongside Cilium. See the variable description for why deleting them afterwards is not equivalent."
  }
}
