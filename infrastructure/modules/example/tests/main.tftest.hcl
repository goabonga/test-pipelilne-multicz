# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Native Terraform tests (`terraform test`, >= 1.7). They run offline —
# `terraform_data` is built into Terraform, so there is no provider to
# reach and no credentials to hold. That is why the CI job has no login.

run "propagates_its_inputs" {
  command = plan

  variables {
    name = "unit-test"
    tags = { environment = "test" }
  }

  assert {
    condition     = terraform_data.example.input.name == "unit-test"
    error_message = "the name variable is not carried into the resource"
  }

  assert {
    condition     = terraform_data.example.input.tags["environment"] == "test"
    error_message = "the tags variable is not carried into the resource"
  }

  assert {
    condition     = output.name == "unit-test"
    error_message = "the name output does not echo the name variable"
  }
}

run "tags_default_to_empty" {
  command = plan

  variables {
    name = "unit-test"
  }

  assert {
    # length(), not `== {}`: the attribute is a map(string) and the empty
    # object literal is not, so `==` compares different types and always
    # fails ("LHS and RHS values are of different types").
    condition     = length(terraform_data.example.input.tags) == 0
    error_message = "tags should default to an empty map"
  }
}
