# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

terraform {
  # >= 1.10 for S3 native state locking (`use_lockfile`). Below that the
  # backend needs a DynamoDB table, which this bootstrap deliberately does
  # not create — see ../README.md.
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
