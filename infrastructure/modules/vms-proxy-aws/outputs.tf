# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "nlb_dns_name" {
  value       = aws_lb.proxy.dns_name
  description = "What workloads point their proxy setting at."
}

output "nlb_arn" {
  value       = aws_lb.proxy.arn
  description = "The internal load balancer in front of the fleet."
}

output "size" {
  value       = local.size
  description = "How many proxies are running. One is a single point of failure for the whole estate's egress; ha makes it more."
}

output "allowed_domains" {
  value       = var.allowed_domains
  description = "The destinations this environment may reach. Exported so the policy is readable from a plan rather than only from a rendered file on a disk."
}
