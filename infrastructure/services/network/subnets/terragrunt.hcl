# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# network/subnets
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
  cfg    = local.config.services.network.subnets
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/network-subnets-${local.config.provider}"
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
  # Placeholders shaped like the real outputs. A plan before the VPC exists
  # has to get SOMETHING back; an empty map fails on the first attribute
  # access with an error about the mock rather than about the ordering.
  mock_outputs = {
    id   = "projects/mock/global/networks/mock"
    name = "mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = merge(
  {
    name        = "shomer-${local.env}-network-subnets"
    environment = local.env
    region      = local.config.region
    project     = try(local.config.project, null)
    tags        = merge(local.config.tags, { config-version = local.config.version })

    # Straight from the config: the three purposes and their ranges. The
    # modules validate the shape rather than trusting it, because a typo in
    # `purpose` produces a subnet that silently gets no route and no rules.
    subnets = local.config.network.subnets
  },

  # The two implementations genuinely take different inputs, and `hcl
  # validate --inputs --strict` refuses a key a module does not declare —
  # so each set is added or omitted, never passed as null.
  #
  # Expanded from a list rather than chosen by a ternary. HCL rejects a
  # conditional whose branches are objects with different attributes, even
  # when one branch is `{}`, and reports it as "Inconsistent conditional
  # result types" — which names the types and not the reason. A list that
  # is empty or holds one object sidesteps the unification entirely:
  # merge() over nothing is {}.

  # GCP subnets are regional and carry the GKE ranges as secondary ranges
  # on the subnet itself.
  merge([for _ in(local.config.provider == "gcp" ? [1] : []) : {
    network_id    = dependency.network_vpc.outputs.id
    pods_cidr     = local.config.network.pods
    services_cidr = local.config.network.services
  }]...),

  # AWS subnets are zonal, so the module makes one per purpose per zone and
  # derives the ranges. EKS takes pod addresses from the subnet itself,
  # which is why there is no pods_cidr here.
  merge([for _ in(local.config.provider == "aws" ? [1] : []) : {
    vpc_id = dependency.network_vpc.outputs.id
    zones  = local.config.zones
  }]...),
)
