# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every AWS call.
#
# The Squid assertions are deliberately the same as the GCP module's: the
# two fleets share one config template precisely so that neither cloud can
# drift into being the permissive one, and a test that only guards one side
# would let exactly that happen.

mock_provider "aws" {}

variables {
  name              = "shomer-test-proxy"
  environment       = "test"
  region            = "eu-west-3"
  vpc_id            = "vpc-0123456789abcdef0"
  subnet_ids        = ["subnet-aaa"]
  security_group_id = "sg-aaa"
  image_id          = "ami-0123456789abcdef0"
  client_cidrs      = ["10.10.0.0/20"]
  allowed_domains   = [".debian.org", ".googleapis.com"]
}

run "the_instances_have_no_public_address" {
  command = plan

  # A public address bypasses the NAT. The fleet would still work — that is
  # the danger — and would silently stop being seen from the reserved
  # egress addresses, breaking every external allow-list.
  assert {
    condition     = length(aws_launch_template.proxy.network_interfaces) == 0
    error_message = "A network_interfaces block with associate_public_ip_address would give the fleet a path out that skips the NAT."
  }
}

run "metadata_v1_is_refused" {
  command = plan

  # The v1 endpoint answers any process that can make an HTTP request to a
  # link-local address — including, on a forward proxy, one reached through
  # a request the proxy was asked to make. That is the classic path from
  # "can reach the proxy" to "holds the instance's credentials", and it is
  # the single most important line in this file.
  assert {
    condition     = aws_launch_template.proxy.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv1 on a forward proxy turns a request the proxy was asked to make into a credential read."
  }

  assert {
    condition     = aws_launch_template.proxy.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "A hop limit above one lets a container on the host reach the metadata service."
  }
}

run "the_root_volume_is_encrypted" {
  command = plan

  assert {
    condition     = aws_launch_template.proxy.block_device_mappings[0].ebs[0].encrypted
    error_message = "The proxy's disk holds the logs of everything the estate asked for."
  }
}

run "the_rendered_config_denies_by_default" {
  command = plan

  # The same three properties the GCP module asserts, against the same
  # template. Squid evaluates http_access in order, so the trailing deny is
  # what makes the allow above it a list rather than a suggestion.
  assert {
    condition     = can(regex("http_access deny all", local.squid_conf))
    error_message = "Without a trailing deny, Squid forwards everything the rules above did not explicitly refuse."
  }

  assert {
    condition     = can(regex("http_access allow workload allowed", local.squid_conf))
    error_message = "The allow must require both the client range and the destination list, not either."
  }

  assert {
    condition     = index(split("\n", local.squid_conf), "http_access deny !Safe_ports") < index(split("\n", local.squid_conf), "http_access allow workload allowed")
    error_message = "The port denies must come before the allow, or a CONNECT to any port is forwarded."
  }
}

run "an_empty_allow_list_is_refused" {
  command = plan

  variables {
    allowed_domains = []
  }

  expect_failures = [var.allowed_domains]
}

run "an_allow_all_domain_is_refused" {
  command = plan

  variables {
    allowed_domains = ["."]
  }

  expect_failures = [var.allowed_domains]
}

run "the_world_cannot_be_a_client" {
  command = plan

  variables {
    client_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.client_cidrs]
}

run "the_load_balancer_is_internal" {
  command = plan

  # An internet-facing load balancer here would publish the proxy to the
  # world, which is an open relay reachable from anywhere.
  assert {
    condition     = aws_lb.proxy.internal
    error_message = "A public load balancer in front of a forward proxy is an open relay."
  }
}

run "ha_never_dips_below_the_current_size" {
  command = plan

  variables {
    ha         = true
    subnet_ids = ["subnet-aaa", "subnet-bbb"]
  }

  assert {
    condition     = aws_autoscaling_group.proxy.desired_capacity == 2
    error_message = "With ha on, a restart or a zone failure must not be an outage for everything behind the proxy."
  }

  # A rolling replace that dips below the current size is a brief and
  # complete outage for the estate's egress.
  assert {
    condition     = aws_autoscaling_group.proxy.instance_refresh[0].preferences[0].min_healthy_percentage == 100
    error_message = "The refresh must keep the whole fleet healthy while replacing it."
  }
}
