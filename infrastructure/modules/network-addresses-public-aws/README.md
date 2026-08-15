# network-addresses-public-aws

**Version:** 0.1.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `network-addresses-public-aws` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/network-addresses-public-aws"
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
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_zones"></a> [zones](#input\_zones) | Zones to place an egress address in, one each.<br/><br/>This is the pool size on AWS. A NAT gateway accepts exactly one<br/>address, so the number of zones IS the number of addresses, and adding<br/>a zone is how the pool grows. | `list(string)` | n/a | yes |
| <a name="input_ip_count"></a> [ip\_count](#input\_ip\_count) | The number of egress addresses the environment config asks for.<br/><br/>Not used to allocate — the zone list decides that — but checked against<br/>it, so a config asking for four addresses in a single-zone environment<br/>fails here rather than quietly receiving one. That mismatch is the kind<br/>of thing discovered under load, months later. | `number` | `1` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_addresses"></a> [addresses](#output\_addresses) | The addresses themselves. THIS IS THE LIST TO HAND TO ANYONE WHO ASKS<br/>what to allow-list. |
| <a name="output_allocation_ids"></a> [allocation\_ids](#output\_allocation\_ids) | Keyed by zone, because a NAT gateway is zonal and must take the address in its own zone. |
| <a name="output_ip_count"></a> [ip\_count](#output\_ip\_count) | How many addresses exist — the zone count, not the requested ip\_count.<br/><br/>Reported separately because on AWS those two numbers can legitimately<br/>differ from what a reader of the environment config expects, and the<br/>pool size is the one that decides how many ports the estate has toward<br/>a single destination. |
<!-- END_TF_DOCS -->
