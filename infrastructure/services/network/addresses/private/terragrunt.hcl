# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# network/addresses/private
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
  cfg    = local.config.services.network.addresses.private

  egress_key = one([for k, v in local.config.network.subnets : k if v.purpose == "egress"])
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/network-addresses-private-${local.config.provider}"
}

# `exclude` rather than a null source: terragrunt drops the unit from the
# run graph before evaluating it, and `run --all` reports it as excluded
# instead of silently doing nothing.
exclude {
  if      = !try(local.cfg.enabled, false)
  actions = ["all"]
}

# Explicit dependency: a resource is placed in a subnet, not in a VPC
dependency "network_subnets" {
  config_path = "../../../network/subnets"

  # Lets `plan` work before the dependency has ever been applied. Every
  # value is a placeholder — the real ones come from the outputs once the
  # modules declare them.
  mock_outputs = {
    self_links     = { for k, v in local.config.network.subnets : k => "mock" }
    ids            = { for k, v in local.config.network.subnets : k => "mock" }
    cidrs          = { for k, v in local.config.network.subnets : k => v.cidr }
    for_routes     = {}
    ids_by_purpose = { "egress" = ["mock"] }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}


inputs = merge(
  {
    name        = "shomer-${local.env}-proxy-ilb"
    environment = local.env
    region      = local.config.region
    project     = try(local.config.project, null)
    tags        = merge(local.config.tags, { config-version = local.config.version })

    # The one number that has to agree between this unit, the route and the
    # proxy — and none of the three reads it from the others.
    address_index = try(local.cfg.address_index, 10)
  },

  # GCP reserves the address, which is what lets the workload's route point
  # at it before the proxy is built.
  merge([for _ in(local.config.provider == "gcp" ? [1] : []) : {
    subnetwork  = dependency.network_subnets.outputs.self_links[local.egress_key]
    subnet_cidr = local.config.network.subnets[local.egress_key].cidr
  }]...),

  # AWS reserves nothing — there is no such reservation — so the module
  # only decides the addresses, one per zone, for the proxy to claim at
  # attach time.
  merge([for _ in(local.config.provider == "aws" ? [1] : []) : {
    subnet_cidrs = {
      for i, z in local.config.zones :
      z => cidrsubnet(
        local.config.network.subnets[local.egress_key].cidr,
        length(local.config.zones) <= 1 ? 0 : ceil(log(length(local.config.zones), 2)),
        i
      )
    }
  }]...),
)
