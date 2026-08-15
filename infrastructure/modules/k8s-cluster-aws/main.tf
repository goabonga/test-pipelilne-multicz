# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The EKS control plane.
#
# CILIUM ON EKS IS THE OPPOSITE PROBLEM FROM GKE.
#
# There, Cilium is what the platform already runs and the job is not to
# install a second one. Here, AWS installs its OWN dataplane by default —
# the VPC CNI, kube-proxy and CoreDNS — and Cilium has to replace it.
#
# The usual approach is to let EKS install them and then delete the
# aws-node daemonset afterwards. That works and leaves a window: between
# the cluster coming up and the deletion landing, pods get VPC CNI
# addresses and kube-proxy iptables rules, and any policy written for
# Cilium is not being enforced by anything. Nodes that join during the
# window keep the old datapath until they are replaced.
#
# `bootstrap_self_managed_addons = false` closes it: the cluster is created
# with no CNI at all. Nodes stay NotReady until Cilium is installed by
# Flux, which is a loud, obvious state — unlike a cluster that looks
# healthy while enforcing nothing.
#
# What that buys, and what it costs:
#
#   - Upstream CiliumNetworkPolicy, including FQDN rules, is available.
#   - kube-proxy is replaced by eBPF; there are no iptables rules to race.
#   - Nothing runs until the GitOps layer installs Cilium. That is the
#     trade, and it is deliberate: a cluster enforcing nothing should not
#     be able to accept a workload.

resource "aws_eks_cluster" "this" {
  # checkov:skip=CKV_AWS_58: Secrets encryption takes a KMS key, and the key
  # cannot be created by the identity that applies this — the apply role
  # deliberately excludes IAM and KMS administration, so that the apply path
  # has no route to privilege escalation. It is passed in through
  # kms_key_arn and the environment configs carry the TODO.
  #
  # Stating the gap rather than hiding it: until that key exists, Kubernetes
  # secrets are encrypted with the AWS-managed key, which is true at rest
  # and says nothing about who can read them.
  name     = var.name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  # THE CILIUM LINE. No VPC CNI, no kube-proxy, no CoreDNS installed by
  # AWS. See the header for why this is not the same as removing them
  # afterwards.
  bootstrap_self_managed_addons = false

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]

    # PRIVATE ONLY. This is the Kubernetes API, not the applications: it is
    # private in every environment, reached through Session Manager, and it
    # is a different front door from the load balancer that serves the api
    # and the ssr.
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  kubernetes_network_config {
    service_ipv4_cidr = var.service_cidr
    # Cilium replaces kube-proxy entirely, so the ipvs/iptables choice does
    # not apply. Stated for the reader who goes looking for it.
    ip_family = "ipv4"
  }

  # The audit trail. `api` and `audit` are the two that answer "who did
  # this?"; without them the question has no answer and is always asked
  # after the fact.
  enabled_cluster_log_types = var.enabled_log_types

  dynamic "encryption_config" {
    for_each = var.kms_key_arn == null ? [] : [var.kms_key_arn]
    content {
      provider {
        key_arn = encryption_config.value
      }
      resources = ["secrets"]
    }
  }

  access_config {
    # API rather than the aws-auth ConfigMap. The ConfigMap is a single
    # cluster-wide object with no audit trail of its own, edited by hand,
    # where a malformed entry locks everyone out including the pipeline.
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    precondition {
      condition     = length(var.subnet_ids) >= 2
      error_message = "EKS requires subnets in at least two availability zones for the control plane, even when the workloads run in one."
    }
  }
}
