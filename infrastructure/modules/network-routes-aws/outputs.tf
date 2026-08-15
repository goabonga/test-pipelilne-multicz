# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "internet_gateway_id" {
  value       = aws_internet_gateway.this.id
  description = "The only door out of this VPC."
}

output "route_table_ids" {
  value = merge(
    { for k, rt in aws_route_table.proxy : k => rt.id },
    { for k, rt in aws_route_table.workload : k => rt.id },
    { public = aws_route_table.public.id },
  )
  description = "Route tables keyed by subnet, plus the shared public one. Gateway VPC endpoints attach to these."
}

output "workload_route_table_ids" {
  value       = [for rt in aws_route_table.workload : rt.id]
  description = <<-EOT
    The tables with no default route. Named separately because the S3 and
    DynamoDB gateway endpoints must attach to exactly these — a workload
    subnet without them cannot reach either service at all, having no other
    path.
  EOT
}

output "proxy_has_egress" {
  value       = length(aws_route.proxy_default) > 0
  description = "Whether the proxies have a way out yet. False until the NAT exists — readable from a plan rather than inferred from an absent resource."
}
