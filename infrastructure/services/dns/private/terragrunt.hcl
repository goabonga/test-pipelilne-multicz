# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# dns/private
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
  cfg    = local.config.services.dns.private
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/dns-private-${local.config.provider}"
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
  config_path = "../../network/vpc"

  # Lets `plan` work before the dependency has ever been applied. Every
  # value is a placeholder — the real ones come from the outputs once the
  # modules declare them.
  mock_outputs = {
    id        = "vpc-mock"
    name      = "mock"
    self_link = "projects/mock/global/networks/mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = merge(
  {
    name        = "shomer-${local.env}-internal"
    environment = local.env
    region      = local.config.region
    project     = try(local.config.project, null)
    tags        = merge(local.config.tags, { config-version = local.config.version })
    domain      = local.cfg.domain
  },

  # The association is the mechanism on both clouds: a private zone with
  # nothing attached resolves for nobody and creates cleanly while doing so.
  merge([for _ in(local.config.provider == "gcp" ? [1] : []) : {
    networks = [dependency.network_vpc.outputs.self_link]
  }]...),

  merge([for _ in(local.config.provider == "aws" ? [1] : []) : {
    vpc_ids = [dependency.network_vpc.outputs.id]
  }]...),
)
