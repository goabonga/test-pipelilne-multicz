# k8s-nodes-gcp

**Version:** 0.1.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `k8s-nodes-gcp` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/k8s-nodes-gcp"
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
| [google_container_node_pool.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_project_iam_member.nodes](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.nodes](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The cluster this pool joins, from services/k8s/cluster. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_zones"></a> [zones](#input\_zones) | Zones available to this pool. All of them when ha is on, the first otherwise. | `list(string)` | n/a | yes |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Node boot disk. Holds the image layers, which is usually what fills it. | `number` | `100` | no |
| <a name="input_ha"></a> [ha](#input\_ha) | Spread the pool across every zone. The difference between a zone failure costing capacity and costing the cluster. | `bool` | `false` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | Node size. | `string` | `"e2-standard-4"` | no |
| <a name="input_max_nodes"></a> [max\_nodes](#input\_max\_nodes) | Autoscaler ceiling without ha. | `number` | `3` | no |
| <a name="input_max_nodes_ha"></a> [max\_nodes\_ha](#input\_max\_nodes\_ha) | Autoscaler ceiling per zone when ha is on. Per ZONE, and therefore the number that decides the worst-case bill. | `number` | `5` | no |
| <a name="input_min_nodes_ha"></a> [min\_nodes\_ha](#input\_min\_nodes\_ha) | Autoscaler floor per zone when ha is on. Per ZONE — a three-zone production runs three times this. | `number` | `1` | no |
| <a name="input_node_roles"></a> [node\_roles](#input\_node\_roles) | Project roles for the node identity: write logs, write metrics, pull<br/>images. Nothing else.<br/><br/>The default compute service account carries project editor in most<br/>projects, and anything that reads the node's token inherits whatever it<br/>holds — which is why this account exists rather than borrowing that one. | `list(string)` | <pre>[<br/>  "roles/logging.logWriter",<br/>  "roles/monitoring.metricWriter",<br/>  "roles/artifactregistry.reader"<br/>]</pre> | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |
| <a name="input_workload_tag"></a> [workload\_tag](#input\_workload\_tag) | Network tag placed on every node.<br/><br/>THE load-bearing setting in this module. services/network/routes and<br/>services/network/firewall both key on it: it is what sends these nodes'<br/>egress to the proxy and what permits them to reach it. Without it a<br/>pool builds, joins, runs pods and can reach nothing outside the VPC,<br/>with no error anywhere that says why. | `string` | `"workload"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_name"></a> [name](#output\_name) | Pool name. |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | The node identity. Holds logging, monitoring and image pull, and should keep holding no more. |
| <a name="output_workload_tag"></a> [workload\_tag](#output\_workload\_tag) | The tag that routes these nodes' egress through the proxy. Must match what services/network/routes and services/network/firewall expect. |
| <a name="output_zones"></a> [zones](#output\_zones) | Where the pool actually runs. One zone without ha, which makes a zone failure a cluster failure. |
<!-- END_TF_DOCS -->
