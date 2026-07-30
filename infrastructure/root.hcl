# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Terragrunt root for the shomer infrastructure. Every unit under
# services/<name>/ includes this file, so provider wiring, backend wiring
# and the environment config live here once.
#
# Named root.hcl, NOT terragrunt.hcl, and kept outside services/ on
# purpose: `run --all` treats every terragrunt.hcl it finds under the
# working dir as a unit, so a root file named terragrunt.hcl inside
# services/ gets run as if it were one and fails with "Did not find any
# Terraform files". Units reference it with
# find_in_parent_folders("root.hcl").
#
# NO CLOUD PROVIDER IS WIRED YET. That is deliberate — the layout, the
# per-environment config split and the plan/apply pipelines are in place so
# the provider is a fill-in-the-blanks step, not a restructuring. Until it
# is filled in, `terragrunt plan` runs against LOCAL state and no provider,
# which works because no unit declares real resources yet. See the two
# commented blocks at the bottom for what to add.

locals {
  # Which configs/<env>/config.yaml to read. `terragrunt.sh` exports ENV;
  # the plan / apply workflows set it per matrix entry.
  environment = get_env("ENV", "staging")

  config = merge(
    yamldecode(file(find_in_parent_folders(format("configs/%s/config.yaml", local.environment)))),
  )
}

# ─────────────────────────── provider (TODO) ───────────────────────────
#
# Uncomment and adapt once a provider is chosen. `if_exists = "overwrite_
# terragrunt"` means the generated file is owned by terragrunt and
# regenerated on every run; `terragrunt.sh clean` removes it.
#
# generate "provider" {
#   path      = "generated_provider.tf"
#   if_exists = "overwrite_terragrunt"
#   contents  = <<EOF
# provider "<name>" {
#   # ... driven by local.config.provider.* in configs/config.<env>.yaml
# }
# EOF
# }

# ──────────────────────────── backend (TODO) ────────────────────────────
#
# Until this is uncommented, state is LOCAL: it lives in the unit's
# .terragrunt-cache and is thrown away with it. That is fine for validating
# the wiring, and NOT fine for anything real — a CI runner starts from an
# empty cache every job, so every plan looks like a first apply. Wire this
# before the first unit declares a resource that costs money.
#
# remote_state {
#   backend = "<name>"
#   config = {
#     # ... driven by local.config.remote_state.* in configs/<env>/config.yaml
#     key = "${format("%s/%s", local.environment, path_relative_to_include())}/terraform.tfstate"
#   }
#   generate = {
#     path      = "generated_backend.tf"
#     if_exists = "overwrite_terragrunt"
#   }
# }

# NOTE: deliberately no `generate "versions"` block. Every module under
# modules/ declares its own `terraform { required_version / required_
# providers }` in versions.tf — it has to, to stand alone under
# `terraform test` / `terraform validate`. A root-generated versions file
# would land a second such block in the same working directory, which
# Terraform rejects with "Duplicate required providers configuration".
