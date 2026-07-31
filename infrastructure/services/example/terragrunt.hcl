# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Reference unit: shows the include / exclude / inputs pattern every other
# unit follows. It consumes modules/example, which is versioned and
# released on its own (`infra-modules-example`, see multicz.toml) — a unit
# never points at modules/_template, that one is only a scaffold to copy.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  config = include.root.locals.config
}

terraform {
  source = "../../modules/example"
}

# Turning a unit off without deleting it or commenting out its inputs.
# `exclude` is the first-class mechanism for this: terragrunt drops the
# unit from the run graph before evaluating it, and `run --all` reports it
# as excluded instead of silently doing nothing. Every unit should expose
# the toggle this way.
exclude {
  if      = !local.config.services.example.enabled
  actions = ["all"]
}

inputs = {
  name = local.config.services.example.name
  tags = merge(local.config.tags, {
    # The environment's deployed config version, stamped onto the resources
    # themselves. `terraform state show` then answers "which config version
    # produced this?" without cross-referencing git — and since
    # infra-apply.yml is the only thing that moves that version, the tag
    # cannot drift from what was actually applied.
    config-version = local.config.version
  })
}
