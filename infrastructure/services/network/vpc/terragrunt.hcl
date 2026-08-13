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

inputs = {
  name        = "shomer-${local.env}-network-vpc"
  environment = local.env
  region      = local.config.region
  project     = try(local.config.project, null)
  tags        = merge(local.config.tags, { config-version = local.config.version })

  # AWS only. On GCP a network holds no addresses of its own — the subnets
  # carry them — so the module takes no cidr, and passing one anyway fails
  # `hcl validate --inputs --strict`, which is the check that keeps this
  # file honest about what each implementation actually accepts.
  cidr = local.config.provider == "aws" ? local.config.network.cidr : null
}
