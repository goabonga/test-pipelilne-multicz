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
    id                         = "mock"
    name                       = "mock"
    self_links                 = { for k, v in local.config.network.subnets : k => "mock" }
    ids                        = { for k, v in local.config.network.subnets : k => "mock" }
    ids_by_purpose             = { "workload" = ["subnet-mock-a", "subnet-mock-b"], "egress" = ["mock"], "public-lb" = ["mock"] }
    secondary_range_names      = { pods = "mock-pods", services = "mock-services" }
    workload_security_group_id = "sg-mock"
    proxy_security_group_id    = "sg-mock"
    workload_route_table_ids   = []
    proxy_tag                  = "egress-proxy"
    workload_tag               = "workload"
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
    id                         = "mock"
    name                       = "mock"
    self_links                 = { for k, v in local.config.network.subnets : k => "mock" }
    ids                        = { for k, v in local.config.network.subnets : k => "mock" }
    ids_by_purpose             = { "workload" = ["subnet-mock-a", "subnet-mock-b"], "egress" = ["mock"], "public-lb" = ["mock"] }
    secondary_range_names      = { pods = "mock-pods", services = "mock-services" }
    workload_security_group_id = "sg-mock"
    proxy_security_group_id    = "sg-mock"
    workload_route_table_ids   = []
    proxy_tag                  = "egress-proxy"
    workload_tag               = "workload"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

# Explicit dependency: the default route must be gone before a workload can try to use it
dependency "network_routes" {
  config_path = "../../network/routes"

  # Lets `plan` work before the dependency has ever been applied. Every
  # value is a placeholder — the real ones come from the outputs once the
  # modules declare them.
  mock_outputs = {
    id                         = "mock"
    name                       = "mock"
    self_links                 = { for k, v in local.config.network.subnets : k => "mock" }
    ids                        = { for k, v in local.config.network.subnets : k => "mock" }
    ids_by_purpose             = { "workload" = ["subnet-mock-a", "subnet-mock-b"], "egress" = ["mock"], "public-lb" = ["mock"] }
    secondary_range_names      = { pods = "mock-pods", services = "mock-services" }
    workload_security_group_id = "sg-mock"
    proxy_security_group_id    = "sg-mock"
    workload_route_table_ids   = []
    proxy_tag                  = "egress-proxy"
    workload_tag               = "workload"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = merge(
  {
    name        = "shomer-${local.env}"
    environment = local.env
    region      = local.config.region
    project     = try(local.config.project, null)
    tags        = merge(local.config.tags, { config-version = local.config.version })
  },

  # GKE: Dataplane V2 is Cilium, so the work is keeping a SECOND dataplane
  # out. The cluster takes the workload subnet and the secondary range
  # names the subnets unit published.
  merge([for _ in(local.config.provider == "gcp" ? [1] : []) : {
    network_id = dependency.network_vpc.outputs.id
    subnetwork = one([
      for k, v in local.config.network.subnets :
      dependency.network_subnets.outputs.self_links[k] if v.purpose == "workload"
    ])
    pods_range_name     = dependency.network_subnets.outputs.secondary_range_names.pods
    services_range_name = dependency.network_subnets.outputs.secondary_range_names.services
    master_cidr         = local.cfg.master_cidr

    # Who may reach the Kubernetes API. The endpoint is private, so this is
    # who INSIDE the network may reach it — not a public allow-list.
    master_authorized_cidrs = [
      { cidr = local.config.network.cidr, name = "vpc" },
    ]
  }]...),

  # EKS: AWS installs its own dataplane by default, so the work is keeping
  # it out entirely — the module refuses to bootstrap the VPC CNI, and
  # Cilium arrives from the GitOps layer.
  merge([for _ in(local.config.provider == "aws" ? [1] : []) : {
    subnet_ids         = dependency.network_subnets.outputs.ids_by_purpose["workload"]
    security_group_id  = dependency.network_firewall.outputs.workload_security_group_id
    kubernetes_version = local.cfg.version
    service_cidr       = local.cfg.service_cidr

    # Created outside terraform: the apply identity deliberately excludes
    # IAM, so that the apply path has no route to privilege escalation.
    cluster_role_arn = try(local.cfg.cluster_role_arn, "")
  }]...),
)
