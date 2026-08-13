# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every AWS call, so this needs no
# credentials and no network.
#
# The assertions are about the properties the design depends on, not about
# terraform's ability to create a VPC. Each has a failure mode that stays
# quiet until something leaks.

mock_provider "aws" {}

variables {
  name        = "shomer-test"
  environment = "test"
  region      = "eu-west-3"
  cidr        = "10.10.0.0/16"
}

run "the_default_security_group_permits_nothing" {
  # apply, not plan: the rule sets are computed, so at plan time they are
  # unknown and the assertion cannot be evaluated at all. Under
  # mock_provider an apply is still offline, and a declared ingress or
  # egress block would show up here as a known value — which is exactly the
  # regression this guards against.
  command = apply

  variables {
    # Off for this run only. A mocked ARN is a random string, and the flow
    # log resource validates its arguments as ARNs — so an apply with them
    # on fails on the mock rather than on anything this run is about. They
    # have their own run below, at plan.
    flow_logs_enabled = false
  }

  # The one that matters. AWS ships this group allowing all traffic between
  # its members and all egress, and anything created without an explicit
  # `security_groups` argument is placed in it — so an omitted argument,
  # the most ordinary mistake there is, buys a workload the internet access
  # the entire design exists to prevent.
  #
  # Declaring the resource with no ingress and no egress blocks removes
  # every rule. Adding one here would not fail anything else; it would just
  # quietly restore the hole.
  assert {
    condition     = length(aws_default_security_group.this.ingress) == 0
    error_message = "The default security group has an ingress rule. Anything launched without an explicit group would inherit it."
  }

  assert {
    condition     = length(aws_default_security_group.this.egress) == 0
    error_message = "The default security group has an egress rule. That is a path out that does not pass the proxy."
  }

  # Named so that anyone reading a console listing knows it is not a
  # fallback to reach for.
  assert {
    condition     = can(regex("DO-NOT-USE", aws_default_security_group.this.tags["Name"]))
    error_message = "The default group should be named to warn off anyone about to attach something to it."
  }
}

run "dns_is_on_because_private_access_depends_on_it" {
  command = plan

  # A private EKS endpoint and every VPC endpoint resolve through the VPC's
  # DNS. With either flag off they are unreachable, and the failure surfaces
  # as a timeout in a workload rather than as a networking misconfiguration.
  assert {
    condition     = aws_vpc.this.enable_dns_support && aws_vpc.this.enable_dns_hostnames
    error_message = "Both DNS flags are required: private endpoints and VPC endpoints are unreachable without them."
  }
}

run "flow_logs_record_what_was_refused" {
  # apply with overrides. The policy is built from the log group's ARN, so
  # at plan it is unknown and none of this can be asserted; and a mocked
  # ARN is a random string the flow log resource rejects as malformed.
  # Overriding the two mocked ARNs with well-formed ones puts the real
  # rendered policy in front of the assertions.
  command = apply

  override_resource {
    target = aws_cloudwatch_log_group.flow[0]
    values = {
      arn = "arn:aws:logs:eu-west-3:123456789012:log-group:/aws/vpc/shomer-test/flow"
    }
  }

  override_resource {
    target = aws_iam_role.flow[0]
    values = {
      arn = "arn:aws:iam::123456789012:role/shomer-test-flow-logs"
    }
  }

  assert {
    condition     = length(aws_flow_log.this) == 1
    error_message = "Flow logs are the only record that something tried to leave another way."
  }

  assert {
    condition     = aws_flow_log.this[0].traffic_type == "REJECT"
    error_message = "REJECT is the default on purpose: accepted traffic is the normal case and its volume is why flow logs get turned off."
  }

  # A flow-logs role that can write anywhere can also erase the log group
  # recording its own misuse. Most documentation examples use "*".
  assert {
    condition = can(regex(
      "aws/vpc/shomer-test/flow", aws_iam_role_policy.flow[0].policy
    ))
    error_message = "The flow-logs role must be scoped to this VPC's log group, not to every log group in the account."
  }

  assert {
    condition     = !can(regex("\"Resource\":\\s*\"\\*\"", aws_iam_role_policy.flow[0].policy))
    error_message = "The flow-logs role must not grant access to every log group."
  }

  # The service assumes this role on behalf of an account. Without the
  # source conditions, any account that names the ARN can make it do so.
  assert {
    condition     = can(regex("aws:SourceAccount", local.flow_assume_policy))
    error_message = "The trust policy must pin the source account, or the role is a confused deputy."
  }
}

run "flow_logs_can_be_turned_off_whole" {
  command = plan

  variables {
    flow_logs_enabled = false
  }

  # An environment that ships logs elsewhere should not be forced to create
  # a log group, a role and a policy it does not use.
  assert {
    condition     = length(aws_flow_log.this) == 0 && length(aws_iam_role.flow) == 0 && length(aws_cloudwatch_log_group.flow) == 0
    error_message = "Disabling flow logs must leave no orphaned log group or role behind."
  }
}

run "a_public_cidr_is_refused" {
  command = plan

  variables {
    cidr = "172.15.0.0/16"
  }

  # 172.15.0.0/16 sits one block below RFC1918's 172.16.0.0/12 — public
  # space that reads as private at a glance, which is the mistake worth
  # catching. A public range becomes routable the instant a gateway
  # appears, and the subnets, the firewall and the proxy would all still
  # look exactly as intended.
  expect_failures = [aws_vpc.this]
}

run "a_public_cidr_is_allowed_when_said_out_loud" {
  command = plan

  variables {
    cidr              = "172.15.0.0/16"
    allow_public_cidr = true
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "172.15.0.0/16"
    error_message = "The escape hatch must work, or someone will delete the precondition instead of using it."
  }
}

run "a_range_too_small_for_the_layout_is_refused" {
  command = plan

  variables {
    cidr = "10.10.0.0/24"
  }

  # The config asks for a workload /20, a proxy /24 and an lb /24. A /24
  # cannot hold them, and the failure would otherwise arrive one module
  # later as an unhelpful overlap error.
  expect_failures = [var.cidr]
}
