# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

variable "bucket" {
  type        = string
  description = "Name of the S3 bucket holding the Terraform state. Globally unique across all of AWS."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket))
    error_message = "Bucket names are 3-63 chars, lowercase letters, digits, dots and hyphens, and cannot start or end with a separator."
  }
}

variable "region" {
  type        = string
  description = "AWS region the bucket lives in."
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = <<-EOT
    Customer-managed KMS key for bucket encryption. Null uses SSE-S3
    (AES256), which is free and still encrypts at rest; a CMK adds key
    rotation you control and an audit trail of who decrypted state.
    State files contain every attribute of every resource, including
    values marked sensitive in the configuration.
  EOT
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = <<-EOT
    Allow `terraform destroy` to delete a bucket that still holds objects.
    Left false on purpose: the objects here are the only record of what
    exists in the account.
  EOT
}

variable "noncurrent_version_retention_days" {
  type        = number
  default     = 90
  description = <<-EOT
    How long superseded state versions are kept. Versioning is what makes
    a corrupted or truncated state recoverable, so this is the length of
    the undo history, not housekeeping.
  EOT

  validation {
    condition     = var.noncurrent_version_retention_days >= 30
    error_message = "Keep at least 30 days of state history — a bad apply is often noticed days later."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the bucket."
}

variable "access_log_retention_days" {
  type        = number
  default     = 365
  description = <<-EOT
    How long S3 server access logs are kept. These record who read the
    state, so the retention is really "how far back an investigation can
    go" — a year is the usual floor for that.
  EOT

  validation {
    condition     = var.access_log_retention_days >= 30
    error_message = "Access logs shorter than 30 days cannot answer a question raised a month after the fact."
  }
}

# ── GitHub OIDC ─────────────────────────────────────────────────────────
#
# All optional. Empty `github_repository` creates no roles at all and
# leaves this bootstrap as a state bucket.

variable "github_repository" {
  type        = string
  default     = ""
  description = <<-EOT
    owner/repo allowed to assume the roles, e.g.
    "goabonga/test-pipelilne-multicz". Appears in the `sub` condition of
    both trust policies, which is what stops every other repository on
    GitHub from assuming them. Empty disables the whole OIDC section.
  EOT

  validation {
    condition     = var.github_repository == "" || can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must be owner/repo, with exactly one slash."
  }
}

variable "oidc_provider_arn" {
  type        = string
  default     = ""
  description = <<-EOT
    ARN of an EXISTING GitHub OIDC provider to reuse. An account may hold
    only one provider per issuer URL, so if something else already created
    one for token.actions.githubusercontent.com, creating a second fails
    with EntityAlreadyExists. Empty creates it here.

    Find it with:
      aws iam list-open-id-connect-providers
  EOT
}

variable "plan_environment" {
  type        = string
  default     = "production-plan"
  description = <<-EOT
    The GitHub environment infra-plan declares for this cloud's
    environment. It appears verbatim in the OIDC subject, so it must match
    `environment:` in infra-plan.yml — a mismatch fails the exchange with
    "Not authorized to perform sts:AssumeRoleWithWebIdentity", which names
    no claim and looks identical to a missing role.
  EOT
}

variable "apply_workflow" {
  type        = string
  default     = ".github/workflows/infra-apply.yml"
  description = "Workflow file the apply role is pinned to, repo-relative."
}

variable "apply_workflow_ref" {
  type        = string
  default     = "main"
  description = <<-EOT
    Branch the apply workflow must be loaded from. Pinning this is what
    stops a workflow edited on a side branch from assuming the apply role.
  EOT
}

variable "role_prefix" {
  type        = string
  default     = "shomer-ci"
  description = "Prefix for the two roles, suffixed -plan and -apply."
}

variable "plan_policy_arns" {
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  description = <<-EOT
    Managed policies for the plan role. Read-only on infrastructure —
    write access to state is granted inline, because a plan against a
    remote backend must put and delete a lock object.
  EOT
}

variable "apply_policy_arns" {
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/PowerUserAccess"]
  description = <<-EOT
    Managed policies for the apply role.

    PowerUserAccess is a STARTING POINT, not a recommendation. It is broad
    enough to create everything the modules under ../../modules/ will
    declare and too broad to leave in place once they exist — narrow it to
    the services actually used (ec2, eks, elasticloadbalancing, route53)
    when they do.

    It deliberately excludes IAM, so this role cannot grant itself more
    than it has. That also means it CANNOT create the node and service
    roles an EKS cluster needs: when you get there, add narrowly scoped
    iam:CreateRole / iam:PassRole rather than widening this, and know that
    doing so hands the apply path a route to privilege escalation.
  EOT
}
