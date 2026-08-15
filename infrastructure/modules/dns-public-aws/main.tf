# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The public zone — the only thing in this infrastructure the internet is
# meant to read.
#
# The same two guards as the GCP module, for the same reasons: private
# addresses are refused because publishing 10.x tells the world the shape
# of a network that is meant to be private while resolving usefully for
# nobody outside it, and DNS is cached, so a record published by accident
# is out there for its TTL whatever is done next.
#
# DNSSEC here needs a KMS key in us-east-1 — Route 53 is a global service
# and signs only from that region — which is a genuine ordering constraint
# rather than a preference, so it is opt-in and the gap is stated.

resource "aws_route53_zone" "this" {
  # checkov:skip=CKV2_AWS_39: Query logging is wired below but off by
  # default, and the reason is ordering rather than doubt. Route 53 is a
  # global service: it writes query logs only to a CloudWatch group in
  # us-east-1, whatever region the environment runs in, and that group needs
  # a resource policy the apply identity cannot create — the same constraint
  # that keeps IAM and KMS out of its reach.
  #
  # Worth turning on once the group exists: on a public zone the queries
  # are the only record of who is probing names nobody advertised.
  name    = var.domain
  comment = "Public names for ${var.environment}. Only the load balancer belongs here."

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_route53_key_signing_key" "this" {
  count = var.dnssec_key_arn == null ? 0 : 1

  hosted_zone_id             = aws_route53_zone.this.id
  key_management_service_arn = var.dnssec_key_arn
  name                       = "${var.name}-ksk"
}

resource "aws_route53_hosted_zone_dnssec" "this" {
  count = var.dnssec_key_arn == null ? 0 : 1

  hosted_zone_id = aws_route53_key_signing_key.this[0].hosted_zone_id

  depends_on = [aws_route53_key_signing_key.this]
}

resource "aws_route53_query_log" "this" {
  count = var.query_log_group_arn == null ? 0 : 1

  zone_id                  = aws_route53_zone.this.zone_id
  cloudwatch_log_group_arn = var.query_log_group_arn
}

resource "aws_route53_record" "this" {
  for_each = var.records

  zone_id = aws_route53_zone.this.zone_id
  name    = "${each.key}.${var.domain}"
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.values
}
