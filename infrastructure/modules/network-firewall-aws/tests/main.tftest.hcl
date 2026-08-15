# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every AWS call.
#
# A rule that is too wide does not fail, it works better. These assert the
# narrowness rather than the presence.

mock_provider "aws" {}

variables {
  name        = "shomer-test"
  environment = "test"
  region      = "eu-west-3"
  vpc_id      = "vpc-0123456789abcdef0"
}

run "only_the_proxy_may_reach_the_internet" {
  # apply, not plan: a security group id is computed, so at plan every
  # comparison between a rule and the group it belongs to is unknown and
  # cannot be evaluated. Under mock_provider an apply is still offline, and
  # the mocked id is consistent between the group and the rules that
  # reference it.
  command = apply

  # The whole design in one assertion. Every rule in this module that names
  # 0.0.0.0/0 as a destination must belong to the proxy group; a rule on
  # any other group would be a second way out, and it would work.
  assert {
    condition = alltrue([
      for r in values(aws_vpc_security_group_egress_rule.proxy_to_internet) :
      r.security_group_id == aws_security_group.proxy.id
    ])
    error_message = "Something other than the proxy has egress to the internet."
  }

  # The workload's rules reference groups, never ranges. A CIDR rule would
  # let anything that later acquires an address in that range be reached,
  # whether or not it is the thing the rule was written for.
  assert {
    condition = alltrue([
      for r in [
        aws_vpc_security_group_egress_rule.workload_to_proxy,
        aws_vpc_security_group_egress_rule.workload_to_endpoints,
      ] : r.cidr_ipv4 == null && r.referenced_security_group_id != null
    ])
    error_message = "A workload egress rule names a range instead of a group. Group references follow the thing; ranges follow the address."
  }
}

run "the_proxy_is_not_an_open_tunnel" {
  command = plan

  # A proxy that can open any port is a way out for every protocol, not
  # just the ones it proxies — and it is reachable from every workload.
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.proxy_to_internet) == 2
    error_message = "The proxy's internet egress must be limited to the ports it proxies."
  }

  assert {
    condition = alltrue([
      for r in values(aws_vpc_security_group_egress_rule.proxy_to_internet) :
      r.ip_protocol == "tcp" && r.from_port == r.to_port
    ])
    error_message = "The proxy's egress must name single TCP ports, not a range or all protocols."
  }
}

run "the_workload_reaches_the_proxy_on_one_port" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_egress_rule.workload_to_proxy.from_port == 3128 && aws_vpc_security_group_egress_rule.workload_to_proxy.to_port == 3128
    error_message = "The workload may reach the proxy on the proxy port only."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.workload_to_proxy.referenced_security_group_id == aws_security_group.proxy.id
    error_message = "The workload's way out must be the proxy group itself."
  }
}

run "the_load_balancer_accepts_nothing_until_an_environment_decides" {
  command = plan

  # The resting state. An environment that has not said who may reach it
  # should not get a front door open to everyone by default — which is
  # what an empty list would produce if it were read as "no restriction".
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.lb_ingress) == 0
    error_message = "With no ranges given, the load balancer must accept nothing rather than everything."
  }

  assert {
    condition     = output.lb_is_public == false
    error_message = "A plan should say whether this environment is reachable from the internet."
  }
}

run "production_is_public_and_says_so" {
  command = plan

  variables {
    lb_ingress_cidrs = ["0.0.0.0/0"]
  }

  # Only production should reach this state, and it should be visible in a
  # plan rather than deduced from a list of ranges.
  assert {
    condition     = output.lb_is_public == true
    error_message = "An environment open to the internet must report it."
  }

  # Even then, on 443 alone.
  assert {
    condition = alltrue([
      for r in values(aws_vpc_security_group_ingress_rule.lb_ingress) :
      r.from_port == 443 && r.to_port == 443
    ])
    error_message = "The public front door is HTTPS only."
  }
}

run "staging_gets_the_same_module_with_its_own_ranges" {
  command = plan

  variables {
    lb_ingress_cidrs = ["10.10.0.0/16"]
  }

  # The one per-environment difference the brief names. Same code, no
  # second path to keep in step.
  assert {
    condition     = output.lb_is_public == false
    error_message = "An environment given only private ranges is not public."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.lb_ingress) == 1
    error_message = "The given range must produce a rule."
  }
}

run "the_endpoints_answer_but_never_initiate" {
  # apply, not plan: a security group id is computed, so at plan every
  # comparison between a rule and the group it belongs to is unknown and
  # cannot be evaluated. Under mock_provider an apply is still offline, and
  # the mocked id is consistent between the group and the rules that
  # reference it.
  command = apply

  # An endpoint ENI has no reason to open a connection. Declaring the group
  # with an inline egress block and leaving it empty would have had the
  # provider add allow-all outbound, which is the AWS mirror of GCP's
  # implied allow-egress.
  assert {
    condition = length([
      for r in [
        aws_vpc_security_group_egress_rule.workload_to_proxy,
        aws_vpc_security_group_egress_rule.workload_to_endpoints,
        aws_vpc_security_group_egress_rule.workload_internal,
        aws_vpc_security_group_egress_rule.lb_to_workload,
      ] : r if r.security_group_id == aws_security_group.endpoints.id
    ]) == 0
    error_message = "The endpoints group has an egress rule. It answers; it does not initiate."
  }

  # Session Manager, ECR, logs, STS. Without these a node cannot be
  # reached, cannot pull an image and cannot log — and the obvious remedy
  # for those symptoms is a NAT on the workload subnet.
  assert {
    condition = alltrue([
      for s in ["ssm", "ecr.api", "ecr.dkr", "logs"] :
      contains(keys(aws_vpc_endpoint.interface), s)
    ])
    error_message = "Removing an endpoint makes a NAT look necessary, which is how the proxy gets bypassed."
  }
}

run "the_s3_endpoint_goes_on_the_tables_with_no_way_out" {
  command = plan

  variables {
    workload_route_table_ids = ["rtb-aaa", "rtb-bbb"]
  }

  # ECR stores image layers in S3. A workload table without this endpoint
  # cannot reach S3 at all, and the pull fails partway with a network error
  # rather than an access one.
  assert {
    condition     = aws_vpc_endpoint.s3[0].route_table_ids == toset(["rtb-aaa", "rtb-bbb"])
    error_message = "The S3 endpoint must attach to the workload route tables — the ones with no default route."
  }
}

run "a_malformed_ingress_range_is_refused" {
  command = plan

  variables {
    lb_ingress_cidrs = ["10.10.0.0"]
  }

  expect_failures = [var.lb_ingress_cidrs]
}
