# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The node group pods actually run on.
#
# The GCP counterpart's load-bearing line is a network tag. Here it is the
# SUBNET LIST: AWS has no equivalent of a tag-scoped route, so what decides
# whether a node reaches the proxy or the internet is which subnet it sits
# in and which route table that subnet is associated with. Putting a node
# group in the public subnets would give it a default route to the internet
# gateway — working, fast, and bypassing the proxy entirely.
#
# THESE NODES WILL BE NotReady UNTIL CILIUM IS INSTALLED. The cluster is
# created with no CNI on purpose (see modules/k8s-cluster-aws), so a node
# that joins has no pod networking until the GitOps layer installs it. That
# is the intended sequence, not a fault: a cluster enforcing no policy
# should not be able to accept a workload.

locals {
  min = var.ha ? var.min_nodes_ha : 1
  max = var.ha ? var.max_nodes_ha : var.max_nodes
}

# A launch template, purely to control two things the managed node group
# would otherwise decide for itself.
resource "aws_launch_template" "nodes" {
  name_prefix = "${var.name}-"

  # IMDSv2 REQUIRED. The same control as GKE_METADATA on the other side:
  # without it any pod that can make an HTTP request to a link-local
  # address reads the node's credentials, so every pod holds whatever the
  # node role holds.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
    # ONE, not two. A packet from a pod's own network namespace has already
    # taken a hop by the time it reaches the host, so a limit of 1 puts the
    # metadata service out of reach of every pod while leaving it reachable
    # by the kubelet, which runs in the host namespace and is zero hops
    # away.
    #
    # Two is the value usually copied around, and it makes the IMDSv2
    # requirement above only half a control: a pod can still ask, it just
    # has to ask correctly.
    http_put_response_hop_limit = var.metadata_hop_limit
    instance_metadata_tags      = "enabled"
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

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = var.name })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = var.cluster_name
  node_group_name = var.name
  node_role_arn   = var.node_role_arn

  # THE line. Workload subnets only — the ones services/network/routes gave
  # no default route. A public subnet here is a way to the internet that
  # passes neither the proxy nor a rule.
  subnet_ids = var.subnet_ids

  scaling_config {
    min_size     = local.min
    max_size     = local.max
    desired_size = local.min
  }

  update_config {
    # One at a time. A managed group replaces nodes by draining them, and
    # on a small pool draining two at once is a capacity cliff during every
    # upgrade.
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  instance_types = var.instance_types
  capacity_type  = var.capacity_type

  labels = merge({ environment = var.environment }, var.node_labels)
  tags   = merge(var.tags, { Name = var.name })

  lifecycle {
    # The autoscaler owns the desired size once the group exists; terraform
    # reasserting it would fight the scaler on every apply and undo a
    # scale-up mid-incident.
    ignore_changes = [scaling_config[0].desired_size]

    precondition {
      condition     = local.max >= local.min
      error_message = "The autoscaler's ceiling is below its floor."
    }
  }
}
