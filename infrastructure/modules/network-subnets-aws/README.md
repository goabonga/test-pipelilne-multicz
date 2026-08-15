# network-subnets-aws

**Version:** 0.3.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `network-subnets-aws` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/network-subnets-aws"
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
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_subnet.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | The subnets to create, keyed by short name, straight from<br/>`network.subnets` in the environment config. Each becomes one subnet<br/>per zone.<br/><br/>`purpose` is behaviour, not documentation: the routes unit reads it to<br/>decide which subnets get a way out, and it decides which EKS load<br/>balancer tag each subnet carries. | <pre>map(object({<br/>    cidr    = string<br/>    purpose = string<br/>  }))</pre> | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The VPC these subnets belong to, from services/network/vpc. | `string` | n/a | yes |
| <a name="input_zones"></a> [zones](#input\_zones) | Availability zones to spread across, from `zones` in the environment<br/>config. One in staging, three in production.<br/><br/>Each purpose's range is divided evenly between them. The list order is<br/>part of the address assignment, so reordering it renumbers subnets and<br/>replaces them — append, never reorder. | `list(string)` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cidrs"></a> [cidrs](#output\_cidrs) | The ranges that were actually created, not the ones that were asked for. Security groups are written against these so a rule cannot outlive the subnet it names. |
| <a name="output_for_routes"></a> [for\_routes](#output\_for\_routes) | Exactly what services/network/routes takes: id, purpose and zone per<br/>subnet. Shaped here rather than reassembled in the unit, so that adding<br/>a field to the routes module is one change and not a change plus a<br/>reminder to update a terragrunt file nobody is looking at. |
| <a name="output_ids"></a> [ids](#output\_ids) | Subnet ids keyed by <short name>-<zone>. |
| <a name="output_ids_by_purpose"></a> [ids\_by\_purpose](#output\_ids\_by\_purpose) | Subnet ids grouped by purpose. What the cluster, NAT and load balancer<br/>units consume — they care that a subnet is a workload subnet, never<br/>which zone it happens to be in. |
| <a name="output_workload_subnet"></a> [workload\_subnet](#output\_workload\_subnet) | Short name of the subnet pods run in. |
<!-- END_TF_DOCS -->
