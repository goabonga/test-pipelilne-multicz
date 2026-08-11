# network-vpc-gcp

**Version:** 0.2.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `network-vpc-gcp` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/network-vpc-gcp"
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
| [google_compute_network.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_allow_default_internet_route"></a> [allow\_default\_internet\_route](#input\_allow\_default\_internet\_route) | Acknowledge that keeping the default route is intended. Only read when<br/>delete\_default\_routes is false — it exists so that turning the guard<br/>off is a deliberate second act rather than a single flag flip. | `bool` | `false` | no |
| <a name="input_delete_default_routes"></a> [delete\_default\_routes](#input\_delete\_default\_routes) | Remove the 0.0.0.0/0 route to the internet gateway at creation.<br/><br/>True is the design: workloads leave only through the egress proxy, and<br/>services/network/routes installs the routes that are actually wanted. | `bool` | `true` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_routing_mode"></a> [routing\_mode](#input\_routing\_mode) | REGIONAL or GLOBAL. Regional keeps Cloud Router advertisements inside<br/>the region, which is what a single-region deployment wants; GLOBAL is<br/>for a network spanning regions and costs cross-region traffic. | `string` | `"REGIONAL"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_id"></a> [id](#output\_id) | Network id, consumed by subnets, firewall and routes. |
| <a name="output_name"></a> [name](#output\_name) | Network name. |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | Network self link, required by resources that take a URL rather than a name. |
<!-- END_TF_DOCS -->
