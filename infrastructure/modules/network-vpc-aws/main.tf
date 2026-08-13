# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The VPC every other unit hangs off.
#
# The AWS counterpart of modules/network-vpc-gcp, and the differences are
# not cosmetic. A fresh GCP network ships a route to the internet, so that
# module deletes it. A fresh AWS VPC has no internet gateway and therefore
# no route out — but it ships a default security group that permits all
# traffic between its members and all egress, and anything launched without
# an explicit group lands in it. The thing that is open by default differs;
# closing it at creation is the same requirement.

resource "aws_vpc" "this" {
  cidr_block = var.cidr

  # BOTH are required, and for a reason beyond convenience: an EKS cluster
  # with a private API endpoint resolves it through the VPC's DNS, and VPC
  # endpoints — the way a private subnet reaches AWS services without
  # crossing the internet — are unreachable without hostname resolution.
  # Turning either off breaks private access and looks like a networking
  # fault a long way from here.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      # Everything in this design is private. A public range here would
      # make the addresses routable on the internet the moment a gateway
      # appears, and nothing downstream would notice — the subnets, the
      # firewall and the proxy would all be configured exactly as intended.
      condition     = var.allow_public_cidr || can(regex("^(10\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.)", var.cidr))
      error_message = "The VPC CIDR is outside RFC1918 private space. Set allow_public_cidr = true to say that is intended."
    }
  }
}

# THE DEFAULT SECURITY GROUP IS EMPTIED, NOT DELETED.
#
# AWS will not let it be deleted, and it cannot be avoided: every VPC has
# one, and any instance, endpoint or load balancer created without an
# explicit group is placed in it. As shipped it allows all traffic from
# other members and all egress — so the one thing that is meant to be
# impossible here, a workload reaching the internet without passing the
# proxy, is exactly what an omitted `security_groups` argument buys.
#
# Declaring it with no ingress and no egress blocks removes every rule.
# Anything that lands here has no connectivity at all, which is a failure
# that shows up immediately in the thing that was misconfigured rather than
# quietly in the egress path.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-default-DO-NOT-USE"
  })
}

# ── flow logs ───────────────────────────────────────────────────────────
#
# A network whose whole design is "nothing leaves except through the proxy"
# needs a record of what tried. Without this, a workload that finds a way
# out leaves no trace, and the first evidence is somebody else's incident
# report.
#
# REJECT-only by default rather than ALL: accepted traffic in a private
# network is the normal case and its volume is the reason flow logs get
# turned off. What matters here is what was refused.

resource "aws_cloudwatch_log_group" "flow" {
  count = var.flow_logs_enabled ? 1 : 0

  name              = "/aws/vpc/${var.name}/flow"
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = var.flow_logs_kms_key_arn
  tags              = var.tags
}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # jsonencode rather than aws_iam_policy_document: mock_provider mocks
  # every data source in the provider, so a policy built from one is an
  # opaque mock string in tests — the source conditions below could be
  # deleted and the tests would still pass.
  flow_assume_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      # Without these two the flow-logs service can be made to assume this
      # role on behalf of ANY account that names its ARN — the confused
      # deputy this service is a textbook case of.
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:ec2:${var.region}:${local.account_id}:vpc-flow-log/*" }
      }
    }]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "flow" {
  count = var.flow_logs_enabled ? 1 : 0

  name               = "${var.name}-flow-logs"
  description        = "Lets VPC flow logs write to this VPC's log group, and nothing else."
  assume_role_policy = local.flow_assume_policy
  tags               = var.tags
}

resource "aws_iam_role_policy" "flow" {
  count = var.flow_logs_enabled ? 1 : 0

  name = "write-flow-logs"
  role = aws_iam_role.flow[0].id

  # Scoped to this VPC's log group. The example in most documentation uses
  # "*", which lets a compromised flow-logs role write into — and with
  # DeleteLogStream, erase — every log group in the account, including the
  # ones recording the compromise.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
      ]
      Resource = "${aws_cloudwatch_log_group.flow[0].arn}:*"
    }]
  })
}

resource "aws_flow_log" "this" {
  count = var.flow_logs_enabled ? 1 : 0

  vpc_id                   = aws_vpc.this.id
  traffic_type             = var.flow_logs_traffic_type
  iam_role_arn             = aws_iam_role.flow[0].arn
  log_destination          = aws_cloudwatch_log_group.flow[0].arn
  log_destination_type     = "cloud-watch-logs"
  max_aggregation_interval = 60

  tags = merge(var.tags, { Name = "${var.name}-flow" })
}
