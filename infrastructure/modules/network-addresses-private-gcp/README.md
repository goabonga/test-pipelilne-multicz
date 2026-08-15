# network-addresses-private-gcp

**Version:** 0.1.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `network-addresses-private-gcp` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/network-addresses-private-gcp"
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
| [google_compute_address.proxy_ilb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_subnet_cidr"></a> [subnet\_cidr](#input\_subnet\_cidr) | The proxy subnet's range, used only to check the address against.<br/><br/>Without it a typo lands outside the subnet and fails at apply — after<br/>everything before it in the run has already applied. | `string` | n/a | yes |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | The proxy subnet this address is taken from, from services/network/subnets. | `string` | n/a | yes |
| <a name="input_address_index"></a> [address\_index](#input\_address\_index) | Which address in the proxy subnet to reserve, counting from the<br/>network address.<br/><br/>An index rather than an address: both services/network/routes and<br/>services/vms/proxy need to agree on this value without depending on<br/>each other, so it has to be written down — and a written-down address<br/>can land outside the subnet, which fails at apply after everything<br/>before it has already applied. An index cannot.<br/><br/>Four is the lowest usable value; below that are the network address,<br/>the gateway, and two Google reserves. | `number` | `10` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_address"></a> [address](#output\_address) | The proxy's internal address.<br/><br/>Consumed by services/network/routes as the workload's next hop and by<br/>services/vms/proxy as its forwarding rule's address — neither depending<br/>on the other, which is the whole reason this unit exists. |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | The reservation itself. |
<!-- END_TF_DOCS -->
