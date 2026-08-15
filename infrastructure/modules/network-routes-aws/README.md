# network-routes-aws

**Version:** 0.2.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `network-routes-aws` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/network-routes-aws"
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
| [aws_default_route_table.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_route_table) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_route.proxy_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.workload](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.workload](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_default_route_table_id"></a> [default\_route\_table\_id](#input\_default\_route\_table\_id) | The VPC's main route table, from services/network/vpc.<br/><br/>Managed here so it can be emptied. Nothing should use it — every subnet<br/>is associated explicitly — but a subnet added later without an<br/>association inherits it silently, and inheriting nothing is a loud<br/>failure where inheriting a default route is not. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | The subnets to route, keyed as services/network/subnets emits them.<br/><br/>`purpose` decides which table a subnet joins, and therefore whether it<br/>has a way out at all. An unrecognised value is refused rather than<br/>ignored: a subnet that matches no branch would get no association and<br/>fall back to the main table, which reads as "isolated" and is not. | <pre>map(object({<br/>    id      = string<br/>    purpose = string<br/>    zone    = string<br/>  }))</pre> | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The VPC these route tables belong to, from services/network/vpc. | `string` | n/a | yes |
| <a name="input_nat_gateway_ids"></a> [nat\_gateway\_ids](#input\_nat\_gateway\_ids) | NAT gateway per zone, from services/network/nat. Empty until that unit<br/>exists, and empty means the proxies have no default route.<br/><br/>That is the intended resting state, not an outage. Pointing this at the<br/>internet gateway in the meantime would give the proxy fleet unmediated<br/>egress and would work perfectly, which is why it would survive review. | `map(string)` | `{}` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_internet_gateway_id"></a> [internet\_gateway\_id](#output\_internet\_gateway\_id) | The only door out of this VPC. |
| <a name="output_proxy_has_egress"></a> [proxy\_has\_egress](#output\_proxy\_has\_egress) | Whether the proxies have a way out yet. False until the NAT exists — readable from a plan rather than inferred from an absent resource. |
| <a name="output_route_table_ids"></a> [route\_table\_ids](#output\_route\_table\_ids) | Route tables keyed by subnet, plus the shared public one. Gateway VPC endpoints attach to these. |
| <a name="output_workload_route_table_ids"></a> [workload\_route\_table\_ids](#output\_workload\_route\_table\_ids) | The tables with no default route. Named separately because the S3 and<br/>DynamoDB gateway endpoints must attach to exactly these — a workload<br/>subnet without them cannot reach either service at all, having no other<br/>path. |
<!-- END_TF_DOCS -->
