# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The egress proxy fleet — the AWS side of the same policy.
#
# The Squid configuration is the identical template as the GCP module: the
# deny-by-default allow-list is the point of the fleet, and it must not be
# possible for one cloud to be more permissive than the other by accident.
# What differs below is only the machinery that runs it.

locals {
  size = var.ha ? var.ha_size : 1

  squid_conf = templatefile("${path.module}/templates/squid.conf.tftpl", {
    port            = var.port
    client_cidrs    = var.client_cidrs
    allowed_domains = var.allowed_domains
  })

  user_data = templatefile("${path.module}/templates/user-data.sh.tftpl", {
    squid_conf = local.squid_conf
    port       = var.port
  })
}

resource "aws_launch_template" "proxy" {
  name_prefix   = "${var.name}-"
  image_id      = var.image_id
  instance_type = var.instance_type

  vpc_security_group_ids = [var.security_group_id]

  user_data = base64encode(local.user_data)

  iam_instance_profile {
    name = var.instance_profile
  }

  # IMDSv2 REQUIRED, not optional. The v1 endpoint answers any process that
  # can make an HTTP request to a link-local address — including, on a
  # forward proxy, one reached through a request the proxy itself was asked
  # to make. That is the classic path from "can reach the proxy" to "holds
  # the instance's credentials".
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.disk_size_gb
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # NO network_interfaces BLOCK WITH associate_public_ip_address. Its
  # presence is what attaches a public address, and a public address is a
  # way to the internet that bypasses the NAT — the fleet would still work
  # and would silently stop being seen from the reserved egress addresses.

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = var.name })
  }

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = length(var.allowed_domains) > 0
      error_message = "The proxy needs an explicit destination allow-list. An empty one denies everything, which is safe and useless; there is no permissive default here on purpose."
    }

    precondition {
      condition     = length(var.client_cidrs) > 0
      error_message = "No client ranges: nothing would be permitted to use the proxy, and the workloads behind it would fail with connection refused rather than with a policy message."
    }
  }
}

resource "aws_autoscaling_group" "proxy" {
  name_prefix         = "${var.name}-"
  vpc_zone_identifier = var.subnet_ids

  min_size         = local.size
  max_size         = local.size * 2
  desired_capacity = local.size

  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.proxy.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.proxy.arn]

  # Never below the current size. A rolling replace that dips to zero is an
  # outage for everything behind the proxy, which here is everything.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
    }
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = var.name })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# The address the proxy subnets' clients connect to. Internal: a
# network load balancer with no public subnets has no public address.
resource "aws_lb" "proxy" {
  # checkov:skip=CKV_AWS_91: Access logs on this load balancer would record
  # connections between a workload and the proxy — source address, port,
  # bytes — and nothing about what was actually requested or whether policy
  # allowed it. For a forward proxy that is the wrong record: the one that
  # answers "what did it try to reach, and was it refused?" is Squid's own
  # access log, which the rendered config writes to stdout with a format
  # chosen to keep the host on CONNECT, and which ships from there.
  #
  # Enabling both would double the storage and add a bucket to manage for a
  # log nobody would read second.
  name_prefix        = "sqd-"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = var.deletion_protection

  tags = merge(var.tags, { Name = "${var.name}-nlb" })
}

resource "aws_lb_target_group" "proxy" {
  name_prefix = "sqd-"
  port        = var.port
  protocol    = "TCP"
  vpc_id      = var.vpc_id

  # TCP against the listener rather than an HTTP probe: Squid answers HTTP
  # only to requests it accepts, so an HTTP check would have to be exempted
  # from the very policy this fleet exists to apply.
  health_check {
    protocol            = "TCP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 10
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "proxy" {
  load_balancer_arn = aws_lb.proxy.arn
  port              = var.port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy.arn
  }
}
