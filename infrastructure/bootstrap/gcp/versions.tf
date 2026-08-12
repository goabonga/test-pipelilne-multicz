# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Optional, after the first apply: move this bootstrap's own state into
  # the bucket it just created, so the only terraform.tfstate on somebody's
  # laptop stops existing. Uncomment, then:
  #
  #   terraform init -migrate-state
  #
  # Terraform copies the local state up and asks for confirmation. Keep the
  # local file until `terraform state list` against the new backend returns
  # the same resources.
  #
  # The values are literal because a backend block cannot read variables or
  # locals — it is resolved before Terraform evaluates anything. Match them
  # to what the apply printed as `remote_state_yaml`.
  #
  # The prefix does NOT collide with the units under services/, which are
  # written as <environment>/services/<unit>, unless an environment is
  # named "bootstrap".
  #
  # backend "gcs" {
  #   bucket = "shomer-tfstate"
  #   prefix = "bootstrap/gcp"
  # }
}
