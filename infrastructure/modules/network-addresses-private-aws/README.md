# network-addresses-private-aws

**Version:** 0.2.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `network-addresses-private-aws` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/network-addresses-private-aws"
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

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [terraform_data.addresses](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_subnet_cidrs"></a> [subnet\_cidrs](#input\_subnet\_cidrs) | The proxy subnets' ranges, keyed by zone.<br/><br/>A network load balancer takes one address per subnet it sits in, so<br/>there is one address per zone and each must come from that zone's own<br/>range. | `map(string)` | n/a | yes |
| <a name="input_address_index"></a> [address\_index](#input\_address\_index) | Which address in each proxy subnet to claim, counting from the network<br/>address.<br/><br/>An index rather than an address, for the same reason as the GCP module:<br/>the value has to be written down so two units can agree on it without<br/>depending on each other, and a written-down address can land outside<br/>its subnet — which fails at apply, after everything before it has<br/>already applied. An index cannot.<br/><br/>Four is the lowest usable value; below it are the network address, the<br/>VPC router, the DNS server, and one AWS reserves. | `number` | `10` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_addresses"></a> [addresses](#output\_addresses) | The proxy load balancer's private address per zone.<br/><br/>Nothing is reserved — AWS has no such reservation — so these are<br/>claimed by services/vms/proxy through subnet\_mapping. Deciding them<br/>here is what lets the proxy's clients be configured before the load<br/>balancer exists. |
| <a name="output_reserved"></a> [reserved](#output\_reserved) | Constant, and stated because the module's name implies otherwise. AWS<br/>has no reservation for a private address: these are decided here and<br/>claimed at attach time, so nothing holds them in the meantime and a<br/>conflicting claim fails then rather than now. |
<!-- END_TF_DOCS -->
