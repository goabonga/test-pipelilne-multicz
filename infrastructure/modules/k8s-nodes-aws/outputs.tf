# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "name" {
  value       = aws_eks_node_group.this.node_group_name
  description = "Node group name."
}

output "arn" {
  value       = aws_eks_node_group.this.arn
  description = "Node group ARN."
}

output "subnet_ids" {
  value       = var.subnet_ids
  description = <<-EOT
    Where the nodes actually sit. Exported so a plan can be checked against
    the workload subnets — the setting that decides whether egress reaches
    the proxy or an internet gateway.
  EOT
}
