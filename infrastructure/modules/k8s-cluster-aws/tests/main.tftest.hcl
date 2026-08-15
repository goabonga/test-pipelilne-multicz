# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every AWS call.
#
# The assertion that carries this module is one boolean, and the reason it
# matters is not obvious from its name.

mock_provider "aws" {}

variables {
  name               = "shomer-test"
  environment        = "test"
  region             = "eu-west-3"
  subnet_ids         = ["subnet-aaa", "subnet-bbb"]
  security_group_id  = "sg-aaa"
  cluster_role_arn   = "arn:aws:iam::123456789012:role/shomer-test-eks"
  kubernetes_version = "1.31"
  service_cidr       = "172.20.0.0/16"
}

run "the_cluster_comes_up_with_no_cni_of_its_own" {
  command = plan

  # THE line. Letting EKS install the VPC CNI and kube-proxy and deleting
  # them afterwards leaves a window where pods get the wrong datapath and
  # nothing enforces policy — and nodes that join during it keep the old
  # datapath until replaced. A cluster with no CNI is NotReady, which is
  # loud; a cluster enforcing nothing looks healthy.
  assert {
    condition     = aws_eks_cluster.this.bootstrap_self_managed_addons == false
    error_message = "With AWS's addons bootstrapped, Cilium is installed alongside a dataplane that is already programming the pods."
  }

  assert {
    condition     = output.dataplane == "cilium-unmanaged"
    error_message = "A plan should say what enforces policy in this cluster."
  }
}

run "the_api_endpoint_is_private_in_every_environment" {
  command = plan

  # This is the Kubernetes API, not the applications. The load balancer
  # that serves the api and the ssr is a different front door, decided by
  # public_load_balancer in the environment config — conflating the two is
  # how one gets opened while somebody is thinking about the other.
  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_public_access == false
    error_message = "A public Kubernetes API endpoint is reachable from the internet regardless of what the load balancer does."
  }

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_private_access
    error_message = "With neither endpoint enabled the cluster is unmanageable, including by the pipeline."
  }
}

run "the_audit_log_is_on" {
  command = plan

  # The record of who changed what. Always wanted after the fact, when it
  # is too late to enable.
  assert {
    condition     = contains(aws_eks_cluster.this.enabled_cluster_log_types, "audit")
    error_message = "A cluster without an audit log cannot answer the question it will be asked."
  }
}

run "nobody_gets_admin_for_having_run_terraform" {
  command = plan

  # The creator is whatever identity the pipeline assumed. Granting it
  # cluster-admin implicitly means the apply role is a Kubernetes
  # administrator forever, which no reviewer of a Terraform plan would see.
  assert {
    condition     = aws_eks_cluster.this.access_config[0].bootstrap_cluster_creator_admin_permissions == false
    error_message = "The identity that created the cluster should not become its administrator by side effect."
  }

  # API rather than the aws-auth ConfigMap: a single cluster-wide object,
  # edited by hand, with no audit trail, where a malformed entry locks
  # everyone out including the pipeline.
  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API"
    error_message = "The aws-auth ConfigMap has no audit trail and one bad edit locks everyone out."
  }
}

run "self_managed_addons_are_refused" {
  command = plan

  variables {
    allow_self_managed_addons = true
  }

  # The variable exists to be refused, so that the reason lives where
  # somebody would look for it rather than in a commit message.
  expect_failures = [var.allow_self_managed_addons]
}

run "an_audit_free_cluster_is_refused" {
  command = plan

  variables {
    enabled_log_types = ["api"]
  }

  expect_failures = [var.enabled_log_types]
}

run "a_single_subnet_is_refused" {
  command = plan

  variables {
    subnet_ids = ["subnet-aaa"]
  }

  # EKS needs two zones for the control plane even when the workloads run
  # in one, which is why single-zone staging still passes two.
  expect_failures = [var.subnet_ids]
}
