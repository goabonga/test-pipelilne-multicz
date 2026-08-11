# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

terraform {
  # >= 1.7 for `mock_provider` in tests/.
  required_version = ">= 1.7.0"

  # No `required_providers` yet — no provider is wired (see
  # ../../services/terragrunt.hcl). Add the block here, per module, once
  # one is chosen; do NOT generate it from the terragrunt root, or
  # Terraform trips on a duplicate providers configuration.
}
