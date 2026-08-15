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
  description = "The workload subnet. Its secondary ranges become the pod and service ranges."
}

variable "pods_range_name" {
  type        = string
  description = "Name of the pod secondary range, as services/network/subnets published it. A wrong name fails cluster creation with an unhelpful \"range not found\"."
}

variable "services_range_name" {
  type        = string
  description = "Name of the service secondary range, as services/network/subnets published it."
}

variable "master_cidr" {
  type        = string
  default     = "172.16.0.0/28"
  description = <<-EOT
    Range for the control plane's own endpoints. Google peers this into the
    VPC, so it must not overlap anything in the environment CIDR plan —
    including the pod and service ranges, which are the usual collision.

    It cannot be changed after creation.
  EOT

  validation {
    condition     = can(cidrhost(var.master_cidr, 0)) && tonumber(split("/", var.master_cidr)[1]) == 28
    error_message = "master_cidr must be a /28 — GKE accepts no other size."
  }
}

variable "master_authorized_cidrs" {
  type = list(object({
    cidr = string
    name = string
  }))
  description = <<-EOT
    Who may reach the Kubernetes API.

    The endpoint is private, so this is who inside the network may reach it
    — the VPC and whatever the control-plane tunnel emerges from. An empty
    list leaves it reachable by nothing at all, including the pipeline that
    has to manage the cluster.
  EOT

  validation {
    condition     = alltrue([for c in var.master_authorized_cidrs : can(cidrhost(c.cidr, 0))])
    error_message = "Every entry needs a valid CIDR."
  }

  validation {
    condition     = !contains([for c in var.master_authorized_cidrs : c.cidr], "0.0.0.0/0")
    error_message = "0.0.0.0/0 here would authorise the whole internet to reach the API — which the private endpoint would then refuse, making this a confusing no-op rather than a working setting. Name the ranges."
  }
}

variable "release_channel" {
  type        = string
  default     = "REGULAR"
  description = <<-EOT
    RAPID, REGULAR or STABLE.

    Regular by default. UNSPECIFIED — no channel — means no automatic
    patching, which reads as control and is in practice a cluster that
    stops receiving security fixes until somebody remembers.
  EOT

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR or STABLE. Leaving a cluster off a channel stops its security patching."
  }
}

variable "database_encryption_key" {
  type        = string
  default     = null
  description = <<-EOT
    KMS key for etcd secrets. Null uses Google's own, which is encrypted at
    rest and says nothing about who can read it.
  EOT
}

variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Refuse to delete the cluster. On by default; turn it off deliberately when tearing an environment down."
}

variable "datapath_provider_override" {
  type        = string
  default     = null
  description = <<-EOT
    Escape hatch that exists only to be refused, so that the reason is
    written down where somebody would look for it.

    The legacy datapath drops eBPF policy enforcement, and installing
    upstream Cilium alongside GKE's managed one leaves two dataplanes
    programming the same pods — where a CiliumNetworkPolicy that appears
    applied may not be the thing deciding the packet.
  EOT
}

variable "rbac_security_group" {
  type        = string
  default     = null
  description = <<-EOT
    Google Group whose members' RBAC is managed as a group, of the form
    gke-security-groups@<domain>.

    Null binds cluster roles to individual accounts, and revoking somebody
    then means finding every binding that names them rather than removing
    them from a group. Null until the group exists, because naming one that
    does not fails cluster creation.
  EOT
}

variable "binary_authorization" {
  type        = bool
  default     = false
  description = <<-EOT
    Refuse to run an image that no attestor has signed.

    Off by default, and the reason is ordering rather than doubt: enforcing
    mode with no attestor configured blocks every deployment including the
    first. The pipeline already signs images with cosign, so the attestation
    half exists — what is missing is the policy and the attestor, which are
    a project-level concern rather than a cluster one.
  EOT
}
