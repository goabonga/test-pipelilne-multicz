# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

output "name" {
  value       = google_container_cluster.this.name
  description = "Cluster name, consumed by services/k8s/nodes."
}

output "endpoint" {
  value       = google_container_cluster.this.endpoint
  description = "The private API endpoint. Reachable from the VPC and the tunnel, and from nowhere else."
}

output "id" {
  value       = google_container_cluster.this.id
  description = "Cluster id."
}

output "workload_pool" {
  value       = "${var.project}.svc.id.goog"
  description = "The workload identity pool. Pods get a Google identity from their Kubernetes service account rather than borrowing the node's."
}

output "dataplane" {
  value       = "cilium-dataplane-v2"
  description = <<-EOT
    What enforces network policy in this cluster, stated so a plan answers
    it rather than a wiki.

    Dataplane V2 is Cilium, managed by Google. Standard NetworkPolicy is
    enforced by its eBPF datapath; upstream CiliumNetworkPolicy CRDs are
    NOT installable alongside it. Pod-to-world egress remains the proxy's
    business.
  EOT
}
