# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# `terraform_data` is a managed resource built into Terraform itself
# (>= 1.4, the official replacement for null_resource) — it needs no
# provider and no credentials, which is what makes it usable here while
# infrastructure/root.hcl still has its provider block commented out.
#
# It exists to give the plan/apply pipeline something real to move: a plan
# on this module reports "1 to add", which is what opens the deploy PR.
# Replace it with real resources when a provider is wired.
resource "terraform_data" "example" {
  # Any change to `input` forces a replacement, so editing name or tags in
  # configs/<env>/config.yaml produces a visible diff on the next plan.
  input = {
    name = var.name
    tags = var.tags
  }
}
