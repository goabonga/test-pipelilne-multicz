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
