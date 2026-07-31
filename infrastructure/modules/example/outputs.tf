# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "id" {
  description = "Identifier of the resource this module manages."
  value       = terraform_data.example.id
}

output "name" {
  description = "Name the module was given, echoed back for consumers."
  value       = var.name
}
