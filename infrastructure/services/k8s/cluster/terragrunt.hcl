# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# k8s/cluster
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
  cfg    = local.config.services.k8s.cluster
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/k8s-cluster-${local.config.provider}"
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
  config_path = "../../network/subnets"

  # Lets `plan` work before the dependency has ever been applied. Every
  # value is a placeholder — the real ones come from the outputs once the
  # modules declare them.
  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

# Explicit dependency: no instance may exist for a second in a permissive network
dependency "network_firewall" {
  config_path = "../../network/firewall"

  # Lets `plan` work before the dependency has ever been applied. Every
  # value is a placeholder — the real ones come from the outputs once the
  # modules declare them.
  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

# Explicit dependency: the default route must be gone before a workload can try to use it
dependency "network_routes" {
  config_path = "../../network/routes"

  # Lets `plan` work before the dependency has ever been applied. Every
  # value is a placeholder — the real ones come from the outputs once the
  # modules declare them.
  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  name        = "shomer-${local.env}-k8s-cluster"
  environment = local.env
  region      = local.config.region
  project     = try(local.config.project, null)
  tags        = merge(local.config.tags, { config-version = local.config.version })
}
