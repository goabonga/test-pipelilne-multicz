# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline. `mock_provider` intercepts every AWS call, so this needs no
# credentials and no network — the same contract as the modules under
# ../../modules/, and the reason `make infra-test` has no cloud login.
#
# What is worth asserting here is not "terraform can create a bucket" but
# the properties that make the bucket safe to hold state. Every one of
# these has a failure mode that is silent until it matters.

mock_provider "aws" {}

variables {
  bucket = "shomer-tfstate-test"
  region = "eu-west-3"
}

run "versioning_is_enabled" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "Without versioning a truncated state is unrecoverable, and the lock file cannot be safely overwritten."
  }
}

run "bucket_is_private" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.state.block_public_acls,
      aws_s3_bucket_public_access_block.state.block_public_policy,
      aws_s3_bucket_public_access_block.state.ignore_public_acls,
      aws_s3_bucket_public_access_block.state.restrict_public_buckets,
    ])
    error_message = "All four public-access blocks must be set; three out of four still leaves a way in."
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.state.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "ACLs must be ignored entirely, or a stray grant can widen access to the state."
  }
}

run "encryption_defaults_to_sse_s3" {
  command = plan

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.state.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "With no CMK the bucket must still encrypt at rest with SSE-S3."
  }
}

run "encryption_uses_the_cmk_when_given" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:eu-west-3:000000000000:key/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.state.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    error_message = "A CMK was supplied and ignored — state would be encrypted with the wrong key."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.state.rule).bucket_key_enabled
    error_message = "S3 Bucket Keys should be on with a CMK — every plan reads this bucket, and each read is a KMS request otherwise."
  }
}

run "state_history_is_kept" {
  command = plan

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.state.rule[0].noncurrent_version_expiration[0].noncurrent_days >= 30
    error_message = "State history shorter than 30 days is not an undo history — a bad apply is often noticed days later."
  }
}

run "plain_http_is_denied" {
  # apply, not plan: the policy interpolates the bucket ARN, which is
  # unknown until the bucket exists. Under mock_provider the apply is
  # still offline — nothing is created anywhere.
  command = apply

  assert {
    condition     = strcontains(aws_s3_bucket_policy.tls_only.policy, "aws:SecureTransport")
    error_message = "State in flight carries the same secrets as state at rest; the bucket policy must deny non-TLS access."
  }
}

run "destroy_is_not_armed_by_default" {
  command = plan

  assert {
    condition     = aws_s3_bucket.state.force_destroy == false
    error_message = "force_destroy defaulting to true would let `terraform destroy` delete the only record of what exists."
  }
}
