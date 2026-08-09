# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The GCS bucket that holds every environment's Terraform state.
#
# This root module runs with LOCAL state, because the thing it creates is
# the remote state backend — see ../README.md for the two-step migration
# that follows the first apply.
#
# The gcs backend locks state natively, so there is no lock table to
# create and no equivalent of the DynamoDB step the AWS side used to need.

provider "google" {
  project = var.project
}

# WHY A SECOND BUCKET
#
# Usage logs record who read the state, and state holds every attribute of
# every resource — including values the configuration marks sensitive.
# Without this, a credential leak leaves no trace of what was taken.
resource "google_storage_bucket" "logs" {
  # checkov:skip=CKV_GCP_62: This IS the log destination. A bucket logging
  # to itself is a loop that grows without bound.
  name                        = "${var.bucket}-logs"
  project                     = var.project
  location                    = var.location
  force_destroy               = var.force_destroy
  labels                      = var.labels
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Not housekeeping — this is what stops someone with write access from
  # deleting the record of what they read.
  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = var.access_log_retention_days
    }
    action {
      type = "Delete"
    }
  }

  # Versioning is on, so deleted log objects become archived rather than
  # disappearing. Without this they accumulate for ever.
  lifecycle_rule {
    condition {
      num_newer_versions = 1
      with_state         = "ARCHIVED"
      age                = var.access_log_retention_days
    }
    action {
      type = "Delete"
    }
  }
}

# The Cloud Storage analytics group is the writer GCS uses for usage logs.
resource "google_storage_bucket_iam_member" "logs_writer" {
  bucket = google_storage_bucket.logs.name
  role   = "roles/storage.objectCreator"
  member = "group:cloud-storage-analytics@google.com"
}

resource "google_storage_bucket" "state" {
  name          = var.bucket
  project       = var.project
  location      = var.location
  force_destroy = var.force_destroy
  labels        = var.labels

  # Versioning is not optional here. It is what turns "someone applied a
  # broken plan" from a rebuild into a rollback.
  versioning {
    enabled = true
  }

  # Uniform access means object ACLs are ignored entirely, so a stray
  # grant cannot widen access to the state.
  uniform_bucket_level_access = true

  # Belt to the project's braces: even if an IAM policy elsewhere grants
  # allUsers, this refuses to make the bucket public.
  public_access_prevention = "enforced"

  dynamic "encryption" {
    for_each = var.kms_key_name == null ? [] : [var.kms_key_name]
    content {
      default_kms_key_name = encryption.value
    }
  }

  logging {
    log_bucket        = google_storage_bucket.logs.name
    log_object_prefix = "gcs-access/"
  }

  lifecycle_rule {
    condition {
      # Superseded generations only — `num_newer_versions` counts how many
      # newer ones exist, so the live object is never matched.
      num_newer_versions         = 1
      days_since_noncurrent_time = var.noncurrent_version_retention_days
      with_state                 = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      # A plan interrupted mid-upload leaves a partial multipart upload
      # that is billed and absent from the object listing.
      age = 7
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }
}
