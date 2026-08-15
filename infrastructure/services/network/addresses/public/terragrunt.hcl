# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# network/addresses/public
#
# EMPTY FOR NOW. The module it points at is a scaffold — no resources yet.
# The wiring is here so the run graph, the provider selection and the
# dependency order are in place and testable before any resource exists.
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
  cfg    = local.config.services.network.addresses.public
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/network-addresses-public-${local.config.provider}"
}

# `exclude` rather than a null source: terragrunt drops the unit from the
# run graph before evaluating it, and `run --all` reports it as excluded
# instead of silently doing nothing.
exclude {
  if      = !try(local.cfg.enabled, false)
  actions = ["all"]
}

# Explicit dependency: everything lives inside the network
dependency "network_vpc" {
  config_path = "../../../network/vpc"

  # Lets `plan` work before the dependency has ever been applied. Every
  # value is a placeholder — the real ones come from the outputs once the
  # modules declare them.
  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = merge(
  {
    name        = "shomer-${local.env}-nat-address"
    environment = local.env
    region      = local.config.region
    project     = try(local.config.project, null)
    tags        = merge(local.config.tags, { config-version = local.config.version })
    ip_count    = local.config.network.nat.ip_count
  },

  # AWS allocates one address per ZONE, because a NAT gateway accepts
  # exactly one and the pool therefore grows by adding zones rather than by
  # raising ip_count. The module checks the two against each other so a
  # config asking for four in a one-zone environment fails rather than
  # quietly receiving one.
  merge([for _ in(local.config.provider == "aws" ? [1] : []) : {
    zones = local.config.zones
  }]...),
)
