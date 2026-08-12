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
# EVERYTHING CLOUD-SPECIFIC IS READ FROM configs/<env>/config.yaml — the
# module each unit runs, the provider block generated below, the backend,
# and the login the pipelines perform. One file per environment decides the
# cloud, so staging on gcp and production on aws is a config difference
# rather than a fork of this file.
#
# Nothing here needs credentials yet: the provider is instantiated lazily
# and the backend falls back to local state until a bucket is declared.
# Both are described where they are defined.

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

  # ── backend ───────────────────────────────────────────────────────────
  #
  # Same key drives it: `remote_state:` in the environment config, pasted
  # from the bootstrap's `remote_state_yaml` output. Absent — the state
  # this repository is in until a bucket exists — the backend is `local`
  # and everything below is unused.
  remote_state_config = try(local.config.remote_state, null)
  has_remote_state    = local.remote_state_config != null

  # The bucket's cloud follows the environment's provider unless the config
  # says otherwise, so `backend:` is one less line to paste wrong. A gcs
  # bucket for an aws environment is legal and occasionally deliberate;
  # this only picks the default.
  backend_default = local.config.provider == "gcp" ? "gcs" : "s3"
  backend_name = (
    local.has_remote_state
    ? try(local.remote_state_config.backend, local.backend_default)
    : "local"
  )

  # The environment prefixes the path, so one bucket holds every
  # environment without collision — staging/services/network-vpc/... and
  # production/services/network-vpc/... never meet. path_relative_to_
  # include() is evaluated against the INCLUDING unit, which is what makes
  # this one line rather than one per unit.
  state_path = format("%s/%s", local.environment, path_relative_to_include())

  backend_s3 = {
    bucket = try(local.remote_state_config.bucket, "")
    region = try(local.remote_state_config.region, local.config.region)
    key    = "${local.state_path}/terraform.tfstate"
    # Native S3 locking (Terraform >= 1.10). Below that, swap for
    # `dynamodb_table` and add the table back to bootstrap/aws.
    use_lockfile = true
    encrypt      = true
  }

  # The gcs backend locks natively; there is nothing to add.
  backend_gcs = {
    bucket = try(local.remote_state_config.bucket, "")
    prefix = local.state_path
  }

  backend_config = (
    local.backend_name == "s3" ? local.backend_s3 :
    local.backend_name == "gcs" ? local.backend_gcs :
    {}
  )
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

# ───────────────────────────── backend ──────────────────────────────────
#
# Selected from the same config as the provider: `remote_state:` present
# means s3 or gcs, absent means local.
#
# THE BACKEND IS NOT LAZY, AND THAT IS THE WHOLE DESIGN CONSTRAINT.
#
# A provider is instantiated only when a resource needs it, so the
# generated provider block above is harmless without credentials. `init`
# configures the backend unconditionally — so hard-coding s3 or gcs here
# before the bucket exists would fail EVERY plan, including the ones
# infra-plan runs to open a PR, with an error about the bucket rather than
# about this file.
#
# Hence the fallback. With no `remote_state:` in the environment config the
# backend is `local` — the same state terragrunt uses today with no block
# at all, in the unit's .terragrunt-cache, thrown away with it. Fine for
# validating wiring; NOT fine for anything real, because a CI runner starts
# from an empty cache every job and so every plan reads as a first apply.
#
# TO TURN IT ON, per environment, once the bucket exists:
#
#   make infra-bootstrap CLOUD=gcp BUCKET=shomer-tfstate PROJECT=... LOCATION=EU
#   # paste the `remote_state_yaml` output under `remote_state:` in
#   # configs/<env>/config.yaml
#
# It takes effect on the next plan, with no change to this file. The two
# environments are independent: staging can be on a real backend while
# production is still local, or the reverse.
remote_state {
  backend = local.backend_name
  config  = local.backend_config

  generate = {
    path      = "generated_backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# NOTE: deliberately no `generate "versions"` block. Every module under
# modules/ declares its own `terraform { required_version / required_
# providers }` in versions.tf — it has to, to stand alone under
# `terraform test` / `terraform validate`. A root-generated versions file
# would land a second such block in the same working directory, which
# Terraform rejects with "Duplicate required providers configuration".
