# k8s-cluster-gcp

**Version:** 0.2.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `k8s-cluster-gcp` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/k8s-cluster-gcp"
}

inputs = {
  name = local.config.services.<unit>.name
  tags = local.config.tags
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_container_cluster.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_master_authorized_cidrs"></a> [master\_authorized\_cidrs](#input\_master\_authorized\_cidrs) | Who may reach the Kubernetes API.<br/><br/>The endpoint is private, so this is who inside the network may reach it<br/>— the VPC and whatever the control-plane tunnel emerges from. An empty<br/>list leaves it reachable by nothing at all, including the pipeline that<br/>has to manage the cluster. | <pre>list(object({<br/>    cidr = string<br/>    name = string<br/>  }))</pre> | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | The VPC, from services/network/vpc. | `string` | n/a | yes |
| <a name="input_pods_range_name"></a> [pods\_range\_name](#input\_pods\_range\_name) | Name of the pod secondary range, as services/network/subnets published it. A wrong name fails cluster creation with an unhelpful "range not found". | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_services_range_name"></a> [services\_range\_name](#input\_services\_range\_name) | Name of the service secondary range, as services/network/subnets published it. | `string` | n/a | yes |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | The workload subnet. Its secondary ranges become the pod and service ranges. | `string` | n/a | yes |
| <a name="input_binary_authorization"></a> [binary\_authorization](#input\_binary\_authorization) | Refuse to run an image that no attestor has signed.<br/><br/>Off by default, and the reason is ordering rather than doubt: enforcing<br/>mode with no attestor configured blocks every deployment including the<br/>first. The pipeline already signs images with cosign, so the attestation<br/>half exists — what is missing is the policy and the attestor, which are<br/>a project-level concern rather than a cluster one. | `bool` | `false` | no |
| <a name="input_database_encryption_key"></a> [database\_encryption\_key](#input\_database\_encryption\_key) | KMS key for etcd secrets. Null uses Google's own, which is encrypted at<br/>rest and says nothing about who can read it. | `string` | `null` | no |
| <a name="input_datapath_provider_override"></a> [datapath\_provider\_override](#input\_datapath\_provider\_override) | Escape hatch that exists only to be refused, so that the reason is<br/>written down where somebody would look for it.<br/><br/>The legacy datapath drops eBPF policy enforcement, and installing<br/>upstream Cilium alongside GKE's managed one leaves two dataplanes<br/>programming the same pods — where a CiliumNetworkPolicy that appears<br/>applied may not be the thing deciding the packet. | `string` | `null` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Refuse to delete the cluster. On by default; turn it off deliberately when tearing an environment down. | `bool` | `true` | no |
| <a name="input_master_cidr"></a> [master\_cidr](#input\_master\_cidr) | Range for the control plane's own endpoints. Google peers this into the<br/>VPC, so it must not overlap anything in the environment CIDR plan —<br/>including the pod and service ranges, which are the usual collision.<br/><br/>It cannot be changed after creation. | `string` | `"172.16.0.0/28"` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_rbac_security_group"></a> [rbac\_security\_group](#input\_rbac\_security\_group) | Google Group whose members' RBAC is managed as a group, of the form<br/>gke-security-groups@<domain>.<br/><br/>Null binds cluster roles to individual accounts, and revoking somebody<br/>then means finding every binding that names them rather than removing<br/>them from a group. Null until the group exists, because naming one that<br/>does not fails cluster creation. | `string` | `null` | no |
| <a name="input_release_channel"></a> [release\_channel](#input\_release\_channel) | RAPID, REGULAR or STABLE.<br/><br/>Regular by default. UNSPECIFIED — no channel — means no automatic<br/>patching, which reads as control and is in practice a cluster that<br/>stops receiving security fixes until somebody remembers. | `string` | `"REGULAR"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_dataplane"></a> [dataplane](#output\_dataplane) | What enforces network policy in this cluster, stated so a plan answers<br/>it rather than a wiki.<br/><br/>Dataplane V2 is Cilium, managed by Google. Standard NetworkPolicy is<br/>enforced by its eBPF datapath; upstream CiliumNetworkPolicy CRDs are<br/>NOT installable alongside it. Pod-to-world egress remains the proxy's<br/>business. |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | The private API endpoint. Reachable from the VPC and the tunnel, and from nowhere else. |
| <a name="output_id"></a> [id](#output\_id) | Cluster id. |
| <a name="output_name"></a> [name](#output\_name) | Cluster name, consumed by services/k8s/nodes. |
| <a name="output_workload_pool"></a> [workload\_pool](#output\_workload\_pool) | The workload identity pool. Pods get a Google identity from their Kubernetes service account rather than borrowing the node's. |
<!-- END_TF_DOCS -->
