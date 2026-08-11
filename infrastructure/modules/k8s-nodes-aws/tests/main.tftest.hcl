# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Native Terraform tests (`terraform test`, >= 1.7). They run offline: a
# `mock_provider` block intercepts every provider call, so no credentials
# and no network are needed — which is why the infra-test CI job needs no
# cloud login.
#
# This placeholder only proves the module evaluates. Replace it with real
# assertions once main.tf declares resources:
#
#   run "creates_the_thing" {
#     command = plan
#     variables { name = "unit-test" }
#     assert {
#       condition     = <resource>.this.name == "unit-test"
#       error_message = "name variable is not propagated"
#     }
#   }

run "module_evaluates" {
  command = plan

  variables {
    name        = "unit-test"
    environment = "test"
    region      = "europe-west1"
    tags        = { environment = "test" }
  }
}
