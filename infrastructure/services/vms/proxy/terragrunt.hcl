# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# vms/proxy
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
  cfg    = local.config.services.vms.proxy
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/vms-proxy-${local.config.provider}"
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
    ids                        = { for k, v in local.config.network.subnets : k => "mock" }
    self_links                 = { for k, v in local.config.network.subnets : k => "mock" }
    ids_by_purpose             = { "public-lb" = ["mock"], "egress" = ["mock"], "workload" = ["mock"] }
    for_routes                 = {}
    proxy_tag                  = "egress-proxy"
    workload_tag               = "workload"
    nat_gateway_ids            = {}
    workload_security_group_id = "sg-mock"
    proxy_security_group_id    = "sg-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

# Explicit dependency: no instance may exist for a second in a permissive network
dependency "network_firewall" {
  config_path = "../../network/firewall"

  # Lets `plan` work before the dependency has ever been applied. Every
  # value is a placeholder — the real ones come from the outputs once the
  # modules declare them.
  mock_outputs = {
    ids                        = { for k, v in local.config.network.subnets : k => "mock" }
    self_links                 = { for k, v in local.config.network.subnets : k => "mock" }
    ids_by_purpose             = { "public-lb" = ["mock"], "egress" = ["mock"], "workload" = ["mock"] }
    for_routes                 = {}
    proxy_tag                  = "egress-proxy"
    workload_tag               = "workload"
    nat_gateway_ids            = {}
    workload_security_group_id = "sg-mock"
    proxy_security_group_id    = "sg-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

# Explicit dependency: the proxy is the only thing allowed an egress path
dependency "network_nat" {
  config_path = "../../network/nat"

  # Lets `plan` work before the dependency has ever been applied. Every
  # value is a placeholder — the real ones come from the outputs once the
  # modules declare them.
  mock_outputs = {
    ids                        = { for k, v in local.config.network.subnets : k => "mock" }
    self_links                 = { for k, v in local.config.network.subnets : k => "mock" }
    ids_by_purpose             = { "public-lb" = ["mock"], "egress" = ["mock"], "workload" = ["mock"] }
    for_routes                 = {}
    proxy_tag                  = "egress-proxy"
    workload_tag               = "workload"
    nat_gateway_ids            = {}
    workload_security_group_id = "sg-mock"
    proxy_security_group_id    = "sg-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = merge(
  {
    name        = "shomer-${local.env}-proxy"
    environment = local.env
    region      = local.config.region
    project     = try(local.config.project, null)
    tags        = merge(local.config.tags, { config-version = local.config.version })

    ha   = local.cfg.ha
    port = local.cfg.port

    # The workload ranges, found by purpose. The firewall says the same
    # thing at the packet layer; saying it twice means a mistake in either
    # one is not enough on its own to open the path.
    client_cidrs = [
      for k, v in local.config.network.subnets : v.cidr if v.purpose == "workload"
    ]

    # THE POLICY. The module refuses an empty list and refuses a wildcard,
    # so this is written out per environment rather than defaulted.
    allowed_domains = local.cfg.allowed_domains
  },

  merge([for _ in(local.config.provider == "aws" ? [1] : []) : {
    vpc_id     = dependency.network_vpc.outputs.id
    subnet_ids = dependency.network_subnets.outputs.ids_by_purpose["egress"]

    # Membership of this group is the capability: it is the only one
    # permitted to reach the internet.
    security_group_id = dependency.network_firewall.outputs.proxy_security_group_id

    # No default. A wrong AMI is a fleet that boots and never listens, and
    # the health check reports it as unhealthy without saying why.
    image_id = local.cfg.image_id
  }]...),

  merge([for _ in(local.config.provider == "gcp" ? [1] : []) : {
    # GCP spreads a regional managed group across zones explicitly. The AWS
    # module takes subnets instead and derives the zones from them, so this
    # key belongs to one implementation and not the other.
    zones      = local.config.zones
    network_id = dependency.network_vpc.outputs.id
    subnetwork = one([
      for k, v in local.config.network.subnets :
      dependency.network_subnets.outputs.self_links[k] if v.purpose == "egress"
    ])
  }]...),
)
