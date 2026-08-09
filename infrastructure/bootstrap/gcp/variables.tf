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
