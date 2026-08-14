# network-subnets-gcp

**Version:** 0.1.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `network-subnets-gcp` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/network-subnets-gcp"
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
| [google_compute_subnetwork.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | The VPC these subnets belong to, from services/network/vpc. | `string` | n/a | yes |
| <a name="input_pods_cidr"></a> [pods\_cidr](#input\_pods\_cidr) | Secondary range for pod addresses, attached to the workload subnet.<br/><br/>It has to be large enough for every pod that will ever run: GKE cannot<br/>grow it after the cluster is created, and the failure mode is a node<br/>pool that will not scale with no obvious reason why. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_services_cidr"></a> [services\_cidr](#input\_services\_cidr) | Secondary range for ClusterIP services, attached to the workload subnet. | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | The subnets to create, keyed by short name, straight from<br/>`network.subnets` in the environment config.<br/><br/>`purpose` is behaviour, not documentation: "workload" is the one that<br/>receives the pod and service ranges, and the routes unit reads the same<br/>key to decide which subnets get a way out. | <pre>map(object({<br/>    cidr    = string<br/>    purpose = string<br/>  }))</pre> | n/a | yes |
| <a name="input_flow_logs_enabled"></a> [flow\_logs\_enabled](#input\_flow\_logs\_enabled) | Record traffic per subnet. The only evidence that something tried to leave another way. | `bool` | `true` | no |
| <a name="input_flow_logs_sampling"></a> [flow\_logs\_sampling](#input\_flow\_logs\_sampling) | Fraction of flows recorded, 0 to 1. Half rather than all: the full rate<br/>on a busy subnet costs more than the incidents it catches, and half<br/>still shows a pattern of attempts. | `number` | `0.5` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cidrs"></a> [cidrs](#output\_cidrs) | The ranges that were actually created. Firewall rules are written against these rather than against the config, so a rule cannot outlive the subnet it names. |
| <a name="output_ids"></a> [ids](#output\_ids) | Subnet ids keyed by the short name from the config. |
| <a name="output_secondary_range_names"></a> [secondary\_range\_names](#output\_secondary\_range\_names) | Names GKE refers to the secondary ranges by. Wrong names fail cluster creation with an unhelpful 'range not found'. |
| <a name="output_self_links"></a> [self\_links](#output\_self\_links) | Subnet self links keyed by short name. What the nodes and NAT units attach to. |
| <a name="output_workload_subnet"></a> [workload\_subnet](#output\_workload\_subnet) | Short name of the subnet pods run in. The cluster unit needs to know which one that is. |
<!-- END_TF_DOCS -->
