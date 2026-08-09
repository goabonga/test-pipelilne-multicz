# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The S3 bucket that holds every environment's Terraform state.
#
# This root module runs with LOCAL state, because the thing it creates is
# the remote state backend — see ../README.md for the two-step migration
# that follows the first apply.
#
# NO DYNAMODB TABLE. Terraform 1.10 locks S3 state with a lock file in the
# bucket itself (`use_lockfile = true` in the backend config). The table
# was the only reason this bootstrap ever needed a second resource, and
# `dynamodb_table` is deprecated as of 1.11.

provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "state" {
  # checkov:skip=CKV_AWS_144: Cross-region replication is not wanted for
  # state. A replica is eventually consistent, so in the disaster it is
  # supposed to cover you would restore a state that may be older than the
  # infrastructure it describes — worse than restoring from a known-good
  # version, which bucket versioning already gives you. Enable it
  # deliberately if a compliance regime demands it, not by default.
  # checkov:skip=CKV2_AWS_62: Event notifications on a state bucket produce
  # an event per plan. There is no consumer here and no meaningful reaction
  # to "state changed" beyond what the pipeline already records.
  bucket        = var.bucket
  force_destroy = var.force_destroy
  tags          = var.tags
}

# WHY A SECOND BUCKET
#
# Server access logs record who read the state, and state holds every
# attribute of every resource — including values the configuration marks
# sensitive. Without this, a credential leak leaves no trace of what was
# taken.
resource "aws_s3_bucket" "logs" {
  # checkov:skip=CKV_AWS_18: This IS the log destination. A bucket logging
  # to itself is a loop that grows without bound.
  # checkov:skip=CKV_AWS_144: See the state bucket — replication of access
  # logs buys nothing that the logs themselves do not already provide.
  # checkov:skip=CKV2_AWS_62: Nothing consumes events on a log bucket.
  # checkov:skip=CKV_AWS_145: SSE-S3 rather than the CMK. Log delivery
  # writes as a service principal, so a customer key would need a policy
  # granting logging.s3.amazonaws.com — for a key this module does not own
  # and that is optional in the first place. A log bucket that silently
  # rejects writes is a worse outcome than one under a managed key.
  bucket        = "${var.bucket}-logs"
  force_destroy = var.force_destroy
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Versioning on the log bucket is not housekeeping — it is what stops
# someone with write access from deleting the record of what they read.
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      # SSE-S3, not the CMK: log delivery cannot assume your key's policy,
      # and a log bucket that silently rejects writes is worse than one
      # encrypted with a managed key.
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  depends_on = [aws_s3_bucket_versioning.logs]

  rule {
    id     = "expire-access-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = var.access_log_retention_days
    }
    # Versioning is on, so deleted log objects become noncurrent rather
    # than disappearing. Without this they accumulate for ever.
    noncurrent_version_expiration {
      noncurrent_days = var.access_log_retention_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Log delivery writes through the service principal, not an ACL — which is
# what lets the log bucket keep BucketOwnerEnforced.
resource "aws_s3_bucket_policy" "logs_delivery" {
  bucket     = aws_s3_bucket.logs.id
  depends_on = [aws_s3_bucket_public_access_block.logs]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowServerAccessLogDelivery"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/*"
        Condition = {
          ArnLike      = { "aws:SourceArn" = aws_s3_bucket.state.arn }
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.logs.arn, "${aws_s3_bucket.logs.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_logging" "state" {
  bucket        = aws_s3_bucket.state.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access/"
}

# Versioning is not optional here. It is what turns "someone applied a
# broken plan" from a rebuild into a rollback, and it is what makes the
# lock file safe to overwrite.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    # Cuts KMS request cost and latency on a bucket read on every plan.
    bucket_key_enabled = var.kms_key_arn != null
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Ownership enforced means ACLs are ignored entirely, so a stray
# grant cannot widen access to the state.
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  # Explicit dependency: applying a lifecycle rule to a bucket whose
  # versioning is still being enabled is a race AWS answers with an error.
  depends_on = [aws_s3_bucket_versioning.state]

  rule {
    id     = "expire-noncurrent-state"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    # A plan interrupted mid-upload leaves a partial multipart upload that
    # is billed and invisible in the console listing.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Deny anything not using TLS. Without this the bucket policy allows
# plain HTTP, and state in flight carries the same secrets as state at
# rest.
resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.state.id

  # Applied after the public access block, or the policy PUT can be
  # rejected while `block_public_policy` is still being evaluated.
  depends_on = [aws_s3_bucket_public_access_block.state]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.state.arn,
        "${aws_s3_bucket.state.arn}/*",
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })
}
