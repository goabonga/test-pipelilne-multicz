# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "workload_security_group_id" {
  value       = aws_security_group.workload.id
  description = "Group for the nodes pods run on. Its egress is the proxy and the endpoints, and nothing else."
}

output "proxy_security_group_id" {
  value       = aws_security_group.proxy.id
  description = "Group for the egress proxies. The only one permitted to reach the internet."
}

output "lb_security_group_id" {
  value       = aws_security_group.lb.id
  description = "Group for the load balancer front end."
}

output "endpoints_security_group_id" {
  value       = aws_security_group.endpoints.id
  description = "Group for the VPC interface endpoints. Answers, never initiates."
}

output "lb_is_public" {
  value       = contains(var.lb_ingress_cidrs, "0.0.0.0/0")
  description = <<-EOT
    Whether this environment's load balancer accepts traffic from the
    internet. Only production should read true, and reading it from a plan
    beats inferring it from a list of ranges.
  EOT
}
