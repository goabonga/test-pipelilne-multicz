# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

variable "bucket" {
  type        = string
  description = "Name of the GCS bucket holding the Terraform state. Globally unique across all of GCS."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", var.bucket))
    error_message = "Bucket names are 3-63 chars, lowercase letters, digits, dots, underscores and hyphens, and cannot start or end with a separator."
  }
}

variable "project" {
  type        = string
  description = "GCP project that owns the bucket."
}

variable "location" {
  type        = string
  description = "Bucket location — a region (europe-west1) or a multi-region (EU)."
}

variable "kms_key_name" {
  type        = string
  default     = null
  description = <<-EOT
    Customer-managed encryption key, as
    projects/<p>/locations/<l>/keyRings/<r>/cryptoKeys/<k>. Null uses
    Google-managed keys, which still encrypt at rest; a CMEK adds
    rotation you control and an audit trail of who decrypted state.
    State files contain every attribute of every resource, including
    values marked sensitive in the configuration.

    The bucket's service agent needs roles/cloudkms.cryptoKeyEncrypter
    Decrypter on the key, or bucket creation fails.
  EOT
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = <<-EOT
    Allow `terraform destroy` to delete a bucket that still holds objects.
    Left false on purpose: the objects here are the only record of what
    exists in the project.
  EOT
}

variable "noncurrent_version_retention_days" {
  type        = number
  default     = 90
  description = <<-EOT
    How long superseded state generations are kept. Object versioning is
    what makes a corrupted state recoverable, so this is the length of the
    undo history.
  EOT

  validation {
    condition     = var.noncurrent_version_retention_days >= 30
    error_message = "Keep at least 30 days of state history — a bad apply is often noticed days later."
  }
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to the bucket."
}

variable "access_log_retention_days" {
  type        = number
  default     = 365
  description = <<-EOT
    How long GCS usage logs are kept. These record who read the state, so
    the retention is really "how far back an investigation can go" — a year
    is the usual floor for that.
  EOT

  validation {
    condition     = var.access_log_retention_days >= 30
    error_message = "Access logs shorter than 30 days cannot answer a question raised a month after the fact."
  }
}

# ── GitHub OIDC ─────────────────────────────────────────────────────────
#
# All optional. Empty `github_repository` creates no identities at all and
# leaves this bootstrap as a state bucket.

variable "github_repository" {
  type        = string
  default     = ""
  description = <<-EOT
    owner/repo allowed to federate into this project, e.g.
    "goabonga/test-pipelilne-multicz". Becomes the provider's attribute
    condition, which is what stops every other repository on GitHub from
    minting a usable token. Empty disables the whole OIDC section.
  EOT

  validation {
    condition     = var.github_repository == "" || can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must be owner/repo, with exactly one slash."
  }
}

variable "plan_environment" {
  type        = string
  default     = "staging-plan"
  description = <<-EOT
    The GitHub environment infra-plan declares for this cloud's
    environment. It appears verbatim in the OIDC subject, so it must match
    `environment:` in infra-plan.yml — a mismatch fails the exchange with
    an unauthorized error naming no claim.
  EOT
}

variable "apply_workflow" {
  type        = string
  default     = ".github/workflows/infra-apply.yml"
  description = "Workflow file the apply identity is pinned to, repo-relative."
}

variable "apply_workflow_ref" {
  type        = string
  default     = "main"
  description = <<-EOT
    Branch the apply workflow must be loaded from. Pinning this is what
    stops a workflow edited on a side branch from assuming the apply
    identity.
  EOT
}

variable "workload_identity_pool_id" {
  type        = string
  default     = "github"
  description = "Pool id. A deleted pool reserves its id for 30 days, so reuse rather than recreate."
}

variable "workload_identity_pool_provider_id" {
  type        = string
  default     = "github"
  description = "Provider id inside the pool."
}

variable "service_account_prefix" {
  type        = string
  default     = "shomer-ci"
  description = "Prefix for the two service accounts, suffixed -plan and -apply."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,22}$", var.service_account_prefix))
    error_message = "Account ids are 6-30 chars total; the prefix must be lowercase and leave room for '-apply'."
  }
}

variable "plan_roles" {
  type        = list(string)
  default     = ["roles/viewer"]
  description = <<-EOT
    Project roles for the plan identity. Read-only on infrastructure —
    write access to state is granted separately on the bucket, because a
    plan against a remote backend must take a lock.
  EOT
}

variable "apply_roles" {
  type        = list(string)
  default     = ["roles/editor"]
  description = <<-EOT
    Project roles for the apply identity.

    roles/editor is a STARTING POINT, not a recommendation. It is broad
    enough to create everything the modules under ../../modules/ will
    declare and too broad to leave in place once they exist — narrow it to
    the services actually used (compute, container, dns) when they do.

    It deliberately excludes roles/owner: editor cannot change IAM, so this
    identity cannot grant itself more than it has.
  EOT
}
