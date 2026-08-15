# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The internal zone.
#
# A Route 53 private zone is visible only to the VPCs associated with it.
# That association is the whole mechanism: a private zone with no VPC
# resolves for nobody and creates cleanly while doing so, and the failure
# surfaces as every internal name being NXDOMAIN — which reads as a records
# problem rather than a zone one.

resource "aws_route53_zone" "this" {
  name    = var.domain
  comment = "Internal names for ${var.environment}. Resolves only inside the VPC."

  dynamic "vpc" {
    for_each = var.vpc_ids
    content {
      vpc_id     = vpc.value
      vpc_region = var.region
    }
  }

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition     = length(var.vpc_ids) > 0
      error_message = "A private zone with no VPC attached resolves for nobody, and creates cleanly while doing so — the failure shows up as every internal name being NXDOMAIN."
    }
  }
}

resource "aws_route53_record" "this" {
  for_each = var.records

  zone_id = aws_route53_zone.this.zone_id
  name    = "${each.key}.${var.domain}"
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.values
}
