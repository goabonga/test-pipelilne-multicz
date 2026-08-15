# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# network/routes
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
  cfg    = local.config.services.network.routes
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/network-routes-${local.config.provider}"
}

# `exclude` rather than a null source: terragrunt drops the unit from the
# run graph before evaluating it, and `run --all` reports it as excluded
# instead of silently doing nothing.
exclude {
  if      = !try(local.cfg.enabled, false)
  actions = ["all"]
}

# Explicit dependency: a resource is placed in a subnet, not in a VPC
dependency "network_vpc" {
  config_path = "../../network/vpc"

  mock_outputs = {
    id                     = "vpc-mock"
    name                   = "mock"
    default_route_table_id = "rtb-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "network_subnets" {
  config_path = "../../network/subnets"

  # Lets `plan` work before the dependency has ever been applied. Every
  # value is a placeholder — the real ones come from the outputs once the
  # modules declare them.
  # Shaped like the real outputs so a plan before the dependency has ever
  # been applied gets something it can index. An empty map fails on the
  # first attribute access with an error about the mock rather than about
  # the ordering.
  mock_outputs = {
    ids        = {}
    for_routes = {}
    self_links = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = merge(
  {
    name        = "shomer-${local.env}-network-routes"
    environment = local.env
    region      = local.config.region
    project     = try(local.config.project, null)
    tags        = merge(local.config.tags, { config-version = local.config.version })
  },

  # Expanded from a list rather than chosen by a ternary: HCL rejects a
  # conditional whose branches are objects with different attributes, even
  # against `{}`. Same idiom as network/vpc and network/subnets.

  # GCP routes are network-wide and selected by instance tag, so this
  # module needs the network and the tags, not the subnets.
  #
  # proxy_ilb_address is deliberately absent: until services/vms/proxy
  # exists there is nothing to point at, and the workload nodes have no
  # default route at all. That is the intended resting state.
  merge([for _ in(local.config.provider == "gcp" ? [1] : []) : {
    network_name = dependency.network_vpc.outputs.name
  }]...),

  # AWS gives each subnet a route table, so the separation is which table a
  # subnet joins — and a subnet with no association silently falls back to
  # the main one, which is why that table is passed in to be emptied.
  #
  # nat_gateway_ids is absent for the same reason as proxy_ilb_address
  # above: no NAT yet, so the proxy subnets have no way out yet.
  merge([for _ in(local.config.provider == "aws" ? [1] : []) : {
    vpc_id                 = dependency.network_vpc.outputs.id
    default_route_table_id = dependency.network_vpc.outputs.default_route_table_id
    subnets                = dependency.network_subnets.outputs.for_routes
  }]...),
)
