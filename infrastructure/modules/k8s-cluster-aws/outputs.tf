# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "name" {
  value       = aws_eks_cluster.this.name
  description = "Cluster name, consumed by services/k8s/nodes."
}

output "endpoint" {
  value       = aws_eks_cluster.this.endpoint
  description = "The private API endpoint. Reachable from inside the VPC and from nowhere else."
}

output "certificate_authority" {
  value       = aws_eks_cluster.this.certificate_authority
  description = "What a kubeconfig needs to trust the endpoint."
}

output "oidc_issuer" {
  value       = aws_eks_cluster.this.identity
  description = "The cluster's OIDC issuer, which is how a pod gets an AWS identity from its Kubernetes service account rather than borrowing the node's."
}

output "dataplane" {
  value       = "cilium-unmanaged"
  description = <<-EOT
    What enforces network policy in this cluster, stated so a plan answers
    it rather than a wiki.

    The cluster is created with NO CNI: upstream Cilium is installed by the
    GitOps layer and replaces kube-proxy. Until it is, nodes are NotReady —
    which is the intended state, because a cluster enforcing nothing should
    not be able to accept a workload.
  EOT
}
