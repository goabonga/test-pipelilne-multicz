# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# network/vpc
#
# The network every other unit hangs off. Both implementations are real.
#
# WHAT IS CLOSED AT CREATION differs by cloud, because what each ships open
# differs: GCP deletes the default 0.0.0.0/0 route, AWS empties the default
# security group. Both end at the same place — a network with no path out
# until services/network/routes puts one back, through the proxy.
#
# PROVIDER SELECTION
#
# `source` is chosen from `provider:` in configs/<env>/config.yaml, so the
# same unit runs the gcp or the aws implementation. Both modules are
# versioned and released independently; neither is reachable unless the
# environment asks for it.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  config = include.root.locals.config
  env    = include.root.locals.environment
  cfg    = local.config.services.network.vpc
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/network-vpc-${local.config.provider}"
}

# `exclude` rather than a null source: terragrunt drops the unit from the
# run graph before evaluating it, and `run --all` reports it as excluded
# instead of silently doing nothing.
exclude {
  if      = !try(local.cfg.enabled, false)
  actions = ["all"]
}

inputs = merge(
  {
    name        = "shomer-${local.env}-network-vpc"
    environment = local.env
    region      = local.config.region
    project     = try(local.config.project, null)
    tags        = merge(local.config.tags, { config-version = local.config.version })
  },

  # cidr is AWS-only: on GCP a network holds no addresses of its own, the
  # subnets carry them, so that module declares no such variable.
  #
  # merge() rather than a ternary on the value, because `cidr = null` still
  # PASSES the key — and `hcl validate --inputs --strict` rejects an input
  # the module does not declare whatever its value. The key has to be
  # absent, not empty. That check is the only thing standing between this
  # file and a quiet claim that both implementations take the same inputs.
  # Expanded from a list rather than chosen by a ternary. With one key a
  # conditional against `{}` happens to unify and lints clean; add a second
  # and HCL rejects it as "Inconsistent conditional result types". Same
  # idiom as network/subnets so the trap is not rediscovered here.
  merge([for _ in(local.config.provider == "aws" ? [1] : []) : {
    cidr = local.config.network.cidr
  }]...)
)
