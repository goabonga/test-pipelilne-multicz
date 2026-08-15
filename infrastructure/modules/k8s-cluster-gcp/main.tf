# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The GKE control plane.
#
# CILIUM ON GKE IS NOT SOMETHING YOU INSTALL.
#
# Dataplane V2 IS Cilium — eBPF, managed by Google, replacing kube-proxy.
# Installing upstream Cilium alongside it is not a stricter arrangement, it
# is two dataplanes fighting: both program eBPF for the same pods, policy
# enforcement becomes order-dependent, and a CiliumNetworkPolicy that
# appears to be applied may not be the thing deciding the packet.
#
# So this module turns Dataplane V2 on and refuses to be configured any
# other way. What that buys, and what it costs, is worth stating plainly:
#
#   - Standard NetworkPolicy is enforced by Cilium's eBPF datapath.
#   - FQDN-based policy is available through GKE's own CRD, not upstream
#     CiliumNetworkPolicy, which is NOT installable here.
#   - Egress to the internet is still the proxy's business. Cilium controls
#     pod-to-pod and pod-to-service; the proxy controls pod-to-world. Both
#     are needed and neither replaces the other.
#
# The node pools are a separate unit. The default pool is removed at
# creation rather than configured, because a pool created with the cluster
# cannot be changed without replacing the cluster.

resource "google_container_cluster" "this" {
  name     = var.name
  project  = var.project
  location = var.region

  network    = var.network_id
  subnetwork = var.subnetwork

  # THE CILIUM LINE. ADVANCED_DATAPATH is Dataplane V2.
  datapath_provider = "ADVANCED_DATAPATH"

  # Redundant with Dataplane V2, which always enforces policy — stated so
  # that turning the datapath back to the legacy one does not silently take
  # policy enforcement with it.
  network_policy {
    enabled = true
  }

  # The pods and services ranges the subnets unit attached, referred to by
  # the names it published. Wrong names fail cluster creation with an
  # unhelpful "range not found".
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # PRIVATE NODES, PRIVATE ENDPOINT. The nodes have no public address, and
  # the control plane is reachable only from inside the VPC and through the
  # tunnel — which is a different question from whether the applications
  # are public, and is private in every environment.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = var.master_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_cidrs
      content {
        cidr_block   = cidr_blocks.value.cidr
        display_name = cidr_blocks.value.name
      }
    }
  }

  # Pods get a Google identity from their Kubernetes service account
  # instead of borrowing the node's. Without it, every pod on a node has
  # whatever that node can do, which is the coarsest possible grant.
  workload_identity_config {
    workload_pool = "${var.project}.svc.id.goog"
  }

  # Secure boot and integrity monitoring on every node this cluster
  # creates. Set here rather than per pool so a pool added later cannot
  # quietly opt out.
  node_config {
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # THE GCP EQUIVALENT OF REQUIRING IMDSv2, and it matters for the same
    # reason. Without GKE_METADATA a pod can read the node's metadata
    # server and take the node's service account token — every pod on the
    # node then holds whatever the node can do, which is precisely what
    # workload identity above is arranged to prevent.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  # Labels, so a cluster is attributable in a bill and in an inventory
  # without asking who made it. Merged with a floor rather than taken from
  # the caller alone: tags defaults to empty, and a cluster nobody can
  # attribute is exactly the one that survives a cost review by being
  # unexplainable.
  resource_labels = merge({
    environment = var.environment
    managed-by  = "terragrunt"
  }, var.tags)

  # Client certificates cannot be revoked and do not expire. Their holder
  # is a cluster administrator until the cluster is rebuilt.
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Traffic between pods on the SAME node never reaches the VPC, so subnet
  # flow logs cannot see it. Without this, the one place an attacker moves
  # laterally is the one place with no record.
  enable_intranode_visibility = true

  # Group-based RBAC. Without it, cluster roles are bound to individual
  # accounts, and revoking someone's access means finding every binding
  # that names them rather than removing them from a group.
  dynamic "authenticator_groups_config" {
    for_each = var.rbac_security_group == null ? [] : [var.rbac_security_group]
    content {
      security_group = authenticator_groups_config.value
    }
  }

  dynamic "binary_authorization" {
    for_each = var.binary_authorization ? [1] : []
    content {
      evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
    }
  }

  # etcd secrets encrypted with a key this project controls, rather than
  # only with Google's. Without it, "encrypted at rest" is true and says
  # nothing about who can read it.
  dynamic "database_encryption" {
    for_each = var.database_encryption_key == null ? [] : [var.database_encryption_key]
    content {
      state    = "ENCRYPTED"
      key_name = database_encryption.value
    }
  }

  release_channel {
    channel = var.release_channel
  }

  # The audit trail. A cluster with no logging cannot answer what happened,
  # and the question is always asked after the fact.
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  # A pool created with the cluster cannot be changed without replacing the
  # cluster, so it is removed and services/k8s/nodes owns the real ones.
  # The initial count is 1 rather than 0 because GKE requires a node to
  # create the cluster at all.
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = var.deletion_protection

  lifecycle {
    precondition {
      condition     = var.datapath_provider_override == null || var.datapath_provider_override == "ADVANCED_DATAPATH"
      error_message = "Only ADVANCED_DATAPATH is supported here. The legacy datapath drops eBPF policy enforcement, and installing upstream Cilium alongside GKE's would leave two dataplanes programming the same pods."
    }

    precondition {
      condition     = length(var.master_authorized_cidrs) > 0
      error_message = "A private endpoint with no authorized networks is reachable by nothing, including the pipeline that has to manage it."
    }
  }
}
