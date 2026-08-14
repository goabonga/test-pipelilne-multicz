# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "ids" {
  value       = { for k, s in aws_subnet.this : k => s.id }
  description = "Subnet ids keyed by <short name>-<zone>."
}

output "cidrs" {
  value       = { for k, s in aws_subnet.this : k => s.cidr_block }
  description = "The ranges that were actually created, not the ones that were asked for. Security groups are written against these so a rule cannot outlive the subnet it names."
}

output "ids_by_purpose" {
  value = {
    for purpose in distinct([for v in local.subnets : v.purpose]) :
    purpose => [for k, v in local.subnets : aws_subnet.this[k].id if v.purpose == purpose]
  }
  description = <<-EOT
    Subnet ids grouped by purpose. What the cluster, NAT and load balancer
    units consume — they care that a subnet is a workload subnet, never
    which zone it happens to be in.
  EOT
}

output "workload_subnet" {
  value       = one([for k, v in var.subnets : k if v.purpose == "workload"])
  description = "Short name of the subnet pods run in."
}
