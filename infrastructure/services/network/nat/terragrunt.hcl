# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# network/nat
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
  cfg    = local.config.services.network.nat

  # The egress subnets, found by purpose rather than by key: renaming a
  # subnet in the config must not leave this translating nothing while
  # still producing a valid plan.
  egress_keys = [for k, v in local.config.network.subnets : k if v.purpose == "egress"]
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/network-nat-${local.config.provider}"
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
  # Shaped from the same config the real outputs are built from, so a plan
  # before the dependency exists indexes the same keys the applied one will.
  # An empty map here fails on the first lookup with "Invalid index", which
  # reads as a bug in this file rather than as a missing dependency.
  mock_outputs = {
    ids            = { for k, v in local.config.network.subnets : k => "mock" }
    self_links     = { for k, v in local.config.network.subnets : k => "mock" }
    ids_by_purpose = { "public-lb" = ["mock"], "egress" = ["mock"], "workload" = ["mock"] }
    for_routes     = { mock = { id = "mock", purpose = "public-lb", zone = try(local.config.zones[0], "mock") } }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

# Explicit dependency: the address is reserved before anything is attached to it
dependency "network_addresses_public" {
  config_path = "../../network/addresses/public"

  # Lets `plan` work before the dependency has ever been applied. Every
  # value is a placeholder — the real ones come from the outputs once the
  # modules declare them.
  # Shaped as the two implementations emit them AND NON-EMPTY. An empty list
  # here is not a neutral placeholder: this module refuses to configure a
  # NAT with no addresses, so an empty mock fails the first plan of a fresh
  # environment with a precondition about reserved addresses — which is
  # correct about the rule and wrong about the situation, and sends the
  # reader to the addresses unit rather than to this mock.
  #
  # A mock has to have the SHAPE of the real output, not merely its type.
  mock_outputs = {
    self_links     = ["mock-address"]
    addresses      = ["203.0.113.1"]
    allocation_ids = { for z in local.config.zones : z => "eipalloc-mock" }
    ip_count       = 1
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}


inputs = merge(
  {
    name        = "shomer-${local.env}-nat"
    environment = local.env
    region      = local.config.region
    project     = try(local.config.project, null)
    tags        = merge(local.config.tags, { config-version = local.config.version })
  },

  # GCP translates for a LIST OF SUBNETS, and the list is the whole control:
  # the default covers every subnet, which would hand the workload egress
  # that passes neither the proxy nor a firewall rule.
  merge([for _ in(local.config.provider == "gcp" ? [1] : []) : {
    network_id  = dependency.network_vpc.outputs.id
    subnetworks = [for k in local.egress_keys : dependency.network_subnets.outputs.self_links[k]]
    nat_ips     = dependency.network_addresses_public.outputs.self_links
  }]...),

  # AWS decides by placement instead: the gateway goes in the PUBLIC subnet
  # — the one with a route to the internet gateway — and who reaches it is
  # settled in services/network/routes. Nothing here can grant the workload
  # egress.
  merge([for _ in(local.config.provider == "aws" ? [1] : []) : {
    public_subnet_ids = {
      for id in dependency.network_subnets.outputs.ids_by_purpose["public-lb"] :
      dependency.network_subnets.outputs.for_routes[
        one([for k, v in dependency.network_subnets.outputs.for_routes : k if v.id == id])
      ].zone => id
    }
    allocation_ids = dependency.network_addresses_public.outputs.allocation_ids
  }]...),
)
