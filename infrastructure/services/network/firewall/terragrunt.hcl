# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# network/firewall
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
  cfg    = local.config.services.network.firewall

  # The proxy subnet's range, found by purpose rather than by key, so that
  # renaming a subnet in the config cannot leave this pointing at nothing
  # while still producing a valid-looking rule.
  proxy_cidr = one([
    for k, v in local.config.network.subnets : local.config.network.subnets[k].cidr
    if v.purpose == "egress"
  ])

  # WHO MAY REACH THE LOAD BALANCER. The one per-environment decision here,
  # and the one the brief states outright: only production is public.
  # Staging gets its own ranges through the same module rather than a
  # second code path that has to be kept in step.
  lb_ingress = try(local.config.services.k8s.cluster.public_load_balancer, false) ? ["0.0.0.0/0"] : [local.config.network.cidr]
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/network-firewall-${local.config.provider}"
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
    id   = "vpc-mock"
    name = "mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "network_subnets" {
  config_path = "../../network/subnets"

  # Lets `plan` work before the dependency has ever been applied. Every
  # value is a placeholder — the real ones come from the outputs once the
  # modules declare them.
  mock_outputs = {
    ids            = {}
    cidrs          = {}
    ids_by_purpose = { workload = [] }
    for_routes     = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "network_routes" {
  config_path = "../../network/routes"

  mock_outputs = {
    workload_route_table_ids = []
    route_table_ids          = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}


inputs = merge(
  {
    name        = "shomer-${local.env}-network-firewall"
    environment = local.env
    region      = local.config.region
    project     = try(local.config.project, null)
    tags        = merge(local.config.tags, { config-version = local.config.version })
  },

  # Expanded from a list rather than chosen by a ternary: HCL rejects a
  # conditional whose branches are objects with different attributes.

  merge([for _ in(local.config.provider == "gcp" ? [1] : []) : {
    network_name      = dependency.network_vpc.outputs.name
    proxy_subnet_cidr = local.proxy_cidr

    # The VPC, the pods and the services. NOT 0.0.0.0/0 — the module
    # refuses that, because listing it here would permit every outbound
    # connection while every other rule still read as strict.
    internal_ranges = [
      local.config.network.cidr,
      local.config.network.pods,
      local.config.network.services,
    ]
  }]...),

  merge([for _ in(local.config.provider == "aws" ? [1] : []) : {
    vpc_id           = dependency.network_vpc.outputs.id
    lb_ingress_cidrs = local.lb_ingress

    # The endpoints put an ENI in each workload subnet and the S3 gateway
    # attaches to the workload route tables — the ones with no default
    # route. Both are what make a private subnet able to reach AWS at all.
    workload_subnet_ids      = dependency.network_subnets.outputs.ids_by_purpose["workload"]
    workload_route_table_ids = dependency.network_routes.outputs.workload_route_table_ids
  }]...),
)
