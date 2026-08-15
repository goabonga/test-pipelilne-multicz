# network-addresses-public-gcp

**Version:** 0.1.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `network-addresses-public-gcp` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/network-addresses-public-gcp"
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
| [google_compute_address.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_ip_count"></a> [ip\_count](#input\_ip\_count) | How many egress addresses to reserve, from `network.nat.ip_count`.<br/><br/>It bounds concurrent outbound connections: each address gives roughly<br/>64k ports shared across everything behind the NAT. One is plenty until<br/>something starts opening thousands of connections to a single<br/>destination, at which point the symptom is intermittent connection<br/>failures under load rather than an obvious limit being hit.<br/><br/>Growing this is safe — new addresses are added to the pool. SHRINKING<br/>IT IS NOT: it releases addresses that external services may have<br/>allow-listed, and the plan in the deploy PR is the only thing that will<br/>say so. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_network_tier"></a> [network\_tier](#input\_network\_tier) | PREMIUM or STANDARD.<br/><br/>Premium by default: standard tier carries egress over the public<br/>internet from the region it leaves, which changes both the path and,<br/>for some destinations, the address geography an allow-list was written<br/>against. | `string` | `"PREMIUM"` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_addresses"></a> [addresses](#output\_addresses) | The addresses themselves. THIS IS THE LIST TO HAND TO ANYONE WHO ASKS<br/>what to allow-list, and the list to check before reducing ip\_count. |
| <a name="output_ip_count"></a> [ip\_count](#output\_ip\_count) | How many addresses are reserved. Consumed by the NAT unit, which must attach every one of them or the estate pays for an address it never uses. |
| <a name="output_self_links"></a> [self\_links](#output\_self\_links) | What Cloud NAT attaches to. |
<!-- END_TF_DOCS -->
