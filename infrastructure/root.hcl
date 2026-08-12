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

  # The provider block, per cloud. Written as two locals and selected,
  # rather than a heredoc inside a conditional — HCL will not parse the
  # latter ("Missing false expression in conditional").
  provider_gcp = <<-EOF
    provider "google" {
      project = "${try(local.config.project, "")}"
      region  = "${local.config.region}"
    }
  EOF

  provider_aws = <<-EOF
    provider "aws" {
      region = "${local.config.region}"

      default_tags {
        tags = ${jsonencode(try(local.config.tags, {}))}
      }
    }
  EOF

  provider_block = local.config.provider == "gcp" ? local.provider_gcp : local.provider_aws
}

# ───────────────────────────── provider ─────────────────────────────────
#
# One generated block per unit, chosen by `provider:` in the environment's
# config. staging can run on gcp while production runs on aws — the units
# already pick their module the same way
# (modules/network-vpc-${local.config.provider}), so this closes the other
# half: the module and the provider that configures it always agree,
# because both read the same key.
#
# `if_exists = "overwrite_terragrunt"` marks the file as terragrunt-owned
# and regenerates it every run; `terragrunt.sh clean` removes it.
#
# WHY THE BLOCK IS EMPTY OF CREDENTIALS
#
# Both providers read their credentials from the environment — GCP from
# GOOGLE_* / application default credentials, AWS from the standard chain
# — which is what the OIDC login in infra-plan / infra-apply populates.
# Putting a key here would mean a long-lived secret in the repository, and
# would also break `terragrunt hcl validate`, which runs with none.
#
# NOTHING IS INSTANTIATED UNTIL A RESOURCE NEEDS IT. Terraform configures a
# provider lazily, so a unit that declares no google/aws resource — as
# services/example does not, it uses terraform_data — still plans without
# credentials. That is what keeps the pipeline green while the modules are
# written.
generate "provider" {
  path      = "generated_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = local.provider_block
}

# ──────────────────────────── backend (TODO) ────────────────────────────
#
# Until this is uncommented, state is LOCAL: it lives in the unit's
# .terragrunt-cache and is thrown away with it. That is fine for validating
# the wiring, and NOT fine for anything real — a CI runner starts from an
# empty cache every job, so every plan looks like a first apply. Wire this
# before the first unit declares a resource that costs money.
#
# The bucket is created once, by hand, by bootstrap/<cloud> — Terraform
# cannot keep its state in a bucket Terraform has not created yet. Run
# `make infra-bootstrap CLOUD=aws|gcp ...`, paste its `remote_state_yaml`
# output under `remote_state:` in configs/<env>/config.yaml, then uncomment
# the block for your cloud below.
#
# Do NOT uncomment before the bucket exists and CI has credentials: this
# takes effect at `init`, so every plan — including the ones infra-plan
# runs on a PR — would fail to reach the backend.
#
# AWS. `use_lockfile` is native S3 locking (Terraform >= 1.10); below that,
# swap it for `dynamodb_table` and add the table to bootstrap/aws.
#
# remote_state {
#   backend = "s3"
#   config = {
#     bucket       = local.config.remote_state.bucket
#     region       = local.config.remote_state.region
#     encrypt      = true
#     use_lockfile = true
#     key          = "${format("%s/%s", local.environment, path_relative_to_include())}/terraform.tfstate"
#   }
#   generate = {
#     path      = "generated_backend.tf"
#     if_exists = "overwrite_terragrunt"
#   }
# }
#
# GCP. The gcs backend locks natively; there is nothing to add.
#
# remote_state {
#   backend = "gcs"
#   config = {
#     bucket = local.config.remote_state.bucket
#     prefix = format("%s/%s", local.environment, path_relative_to_include())
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
