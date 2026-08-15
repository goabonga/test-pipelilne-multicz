# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every AWS call.

mock_provider "aws" {}

variables {
  name          = "shomer-test-pool"
  environment   = "test"
  region        = "eu-west-3"
  cluster_name  = "shomer-test"
  subnet_ids    = ["subnet-workload-a"]
  node_role_arn = "arn:aws:iam::123456789012:role/shomer-test-nodes"
}

run "a_pod_cannot_read_the_nodes_credentials" {
  command = plan

  # The AWS half of the same control GKE_METADATA provides. Without it any
  # pod that can make an HTTP request to a link-local address reads the
  # node's credentials, so every pod holds whatever the node role holds.
  assert {
    condition     = aws_launch_template.nodes.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv1 lets any pod on the node take the node role's credentials."
  }

  # A packet from a pod's namespace has already taken a hop, so 1 puts the
  # metadata service out of every pod's reach while leaving it reachable by
  # the kubelet, which is zero hops away in the host namespace. Two is the
  # value usually copied around, and it makes requiring IMDSv2 only half a
  # control: a pod can still ask, it just has to ask correctly.
  assert {
    condition     = aws_launch_template.nodes.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "A hop limit of 2 leaves the metadata service reachable from inside a pod."
  }
}

run "the_volume_is_encrypted" {
  command = plan

  assert {
    condition     = aws_launch_template.nodes.block_device_mappings[0].ebs[0].encrypted
    error_message = "Node volumes hold image layers and whatever a pod writes to disk."
  }
}

run "the_nodes_sit_where_there_is_no_way_out" {
  command = plan

  # AWS has no tag-scoped route, so the subnet IS the control: a node in a
  # public subnet has a default route to the internet gateway, which works,
  # is fast, and bypasses the proxy entirely.
  assert {
    condition     = aws_eks_node_group.this.subnet_ids == toset(["subnet-workload-a"])
    error_message = "The node group must sit in the workload subnets, which are the ones with no default route."
  }

  assert {
    condition     = length(output.subnet_ids) == 1
    error_message = "A plan should say where the nodes sit, since that is what decides their egress."
  }
}

run "an_upgrade_replaces_one_node_at_a_time" {
  command = plan

  assert {
    condition     = aws_eks_node_group.this.update_config[0].max_unavailable == 1
    error_message = "Draining more than one node at a time is a capacity cliff on a small pool."
  }
}

run "ha_raises_the_floor" {
  command = plan

  variables {
    ha         = true
    subnet_ids = ["subnet-workload-a", "subnet-workload-b", "subnet-workload-c"]
  }

  assert {
    condition     = aws_eks_node_group.this.scaling_config[0].min_size == 3
    error_message = "With ha on the floor should cover a zone failure."
  }
}

run "an_inverted_autoscaler_is_refused" {
  command = plan

  variables {
    max_nodes = 0
  }

  expect_failures = [aws_eks_node_group.this]
}
