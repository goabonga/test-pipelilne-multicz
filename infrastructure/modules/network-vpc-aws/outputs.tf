# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "id" {
  value       = aws_vpc.this.id
  description = "VPC id, consumed by every unit that puts something in it."
}

output "arn" {
  value       = aws_vpc.this.arn
  description = "VPC ARN, for policies that scope to this network."
}

output "cidr" {
  value       = aws_vpc.this.cidr_block
  description = "The range that was actually created, not the one that was asked for."
}

output "default_security_group_id" {
  value       = aws_default_security_group.this.id
  description = <<-EOT
    The emptied default group. Exported so a reader can confirm what it is
    attached to, NOT so anything can be attached to it — it permits nothing
    in either direction by design.
  EOT
}
