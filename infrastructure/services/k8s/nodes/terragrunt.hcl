# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# k8s/nodes
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
  cfg    = local.config.services.k8s.nodes
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/k8s-nodes-${local.config.provider}"
}

# `exclude` rather than a null source: terragrunt drops the unit from the
# run graph before evaluating it, and `run --all` reports it as excluded
# instead of silently doing nothing.
exclude {
  if      = !try(local.cfg.enabled, false)
  actions = ["all"]
}

# Explicit dependency: nodes join a cluster that already exists
dependency "network_subnets" {
  config_path = "../../network/subnets"

  mock_outputs = {
    ids_by_purpose = { "workload" = ["subnet-mock"], "egress" = ["mock"], "public-lb" = ["mock"] }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "k8s_cluster" {
  config_path = "../../k8s/cluster"

  # Lets `plan` work before the dependency has ever been applied. Every
  # value is a placeholder — the real ones come from the outputs once the
  # modules declare them.
  mock_outputs = {
    name                       = "mock"
    id                         = "mock"
    endpoint                   = "mock"
    ids_by_purpose             = { "workload" = ["subnet-mock"], "egress" = ["mock"], "public-lb" = ["mock"] }
    self_links                 = { for k, v in local.config.network.subnets : k => "mock" }
    workload_security_group_id = "sg-mock"
    workload_tag               = "workload"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = merge(
  {
    name         = "shomer-${local.env}-nodes"
    environment  = local.env
    region       = local.config.region
    project      = try(local.config.project, null)
    tags         = merge(local.config.tags, { config-version = local.config.version })
    cluster_name = dependency.k8s_cluster.outputs.name
    ha           = local.cfg.ha
  },

  # GCP decides egress by TAG: the pool carries the workload tag, which is
  # what services/network/routes and services/network/firewall key on.
  merge([for _ in(local.config.provider == "gcp" ? [1] : []) : {
    zones = local.config.zones
  }]...),

  # AWS has no tag-scoped route, so the SUBNET is the control: the workload
  # subnets are the ones with no default route, and a node placed anywhere
  # else would reach the internet without passing the proxy.
  merge([for _ in(local.config.provider == "aws" ? [1] : []) : {
    subnet_ids = dependency.network_subnets.outputs.ids_by_purpose["workload"]

    # Created outside terraform: the apply identity excludes IAM on
    # purpose, so that the apply path has no route to privilege escalation.
    node_role_arn = try(local.cfg.node_role_arn, "")
  }]...),
)
