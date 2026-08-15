# network-nat-aws

**Version:** 0.2.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `network-nat-aws` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/network-nat-aws"
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
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allocation_ids"></a> [allocation\_ids](#input\_allocation\_ids) | Reserved elastic address per zone, from<br/>services/network/addresses/public.<br/><br/>Passed explicitly rather than letting the gateway allocate its own: an<br/>automatic address changes whenever the gateway is recreated, which<br/>breaks every external allow-list while the reserved ones sit unused and<br/>billed. | `map(string)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | The subnet each zone's NAT gateway sits in, keyed by zone — the PUBLIC<br/>subnets, which are the ones with a route to the internet gateway.<br/><br/>Not the proxy subnets, which is the intuitive answer and the wrong one:<br/>a gateway placed there has no way out, and the failure presents as a<br/>routing problem in the workloads behind it. | `map(string)` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_addresses"></a> [addresses](#output\_addresses) | The addresses traffic is seen from. Should match what services/network/addresses/public reserved; if it does not, a gateway allocated its own. |
| <a name="output_nat_gateway_ids"></a> [nat\_gateway\_ids](#output\_nat\_gateway\_ids) | Keyed by zone. services/network/routes consumes this to give each<br/>proxy subnet a default route to the gateway in its OWN zone — a shared<br/>one would cross a zone boundary on every packet and fail as a unit when<br/>that zone did. |
<!-- END_TF_DOCS -->
