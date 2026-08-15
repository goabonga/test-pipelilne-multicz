# network-nat-gcp

**Version:** 0.1.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `network-nat-gcp` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/network-nat-gcp"
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
| [google_compute_router.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_nat_ips"></a> [nat\_ips](#input\_nat\_ips) | Reserved addresses from services/network/addresses/public.<br/><br/>Passed explicitly because the alternative — letting Cloud NAT allocate<br/>its own — works perfectly and changes the egress address whenever the<br/>NAT is recreated, breaking every external allow-list while the reserved<br/>addresses sit unused and billed. | `list(string)` | n/a | yes |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | The VPC the router belongs to, from services/network/vpc. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_subnetworks"></a> [subnetworks](#input\_subnetworks) | Self links of the subnets this NAT translates for — the EGRESS subnets,<br/>and nothing else.<br/><br/>Cloud NAT's default is ALL\_SUBNETWORKS\_ALL\_IP\_RANGES. Taking it would<br/>give the workload subnet a path to the internet that bypasses the<br/>proxy, needs no route, appears in no firewall rule, and works. | `list(string)` | n/a | yes |
| <a name="input_dynamic_port_allocation"></a> [dynamic\_port\_allocation](#input\_dynamic\_port\_allocation) | Let Cloud NAT grow a VM's port allocation on demand up to max\_ports\_per\_vm, rather than reserving the maximum up front. | `bool` | `true` | no |
| <a name="input_log_filter"></a> [log\_filter](#input\_log\_filter) | ERRORS\_ONLY, TRANSLATIONS\_ONLY or ALL.<br/><br/>Errors by default: logging every translation on a busy proxy fleet<br/>produces volume nobody reads and a bill somebody notices, while the<br/>dropped ones are the events that explain a failure. | `string` | `"ERRORS_ONLY"` | no |
| <a name="input_logging_enabled"></a> [logging\_enabled](#input\_logging\_enabled) | Log NAT events. A dropped translation is what explains an outage nobody can otherwise account for. | `bool` | `true` | no |
| <a name="input_max_ports_per_vm"></a> [max\_ports\_per\_vm](#input\_max\_ports\_per\_vm) | Ceiling when dynamic allocation is on. Ignored otherwise. | `number` | `8192` | no |
| <a name="input_min_ports_per_vm"></a> [min\_ports\_per\_vm](#input\_min\_ports\_per\_vm) | Ports held per VM, used or not.<br/><br/>The capacity limit that bites first: each address gives roughly 64k<br/>ports, so a generous number with a small pool exhausts the pool on idle<br/>reservations. The symptom is new connections failing while existing<br/>ones are fine. | `number` | `128` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_nat_name"></a> [nat\_name](#output\_nat\_name) | The NAT itself. |
| <a name="output_router_name"></a> [router\_name](#output\_router\_name) | The router carrying the NAT configuration. |
| <a name="output_translated_subnetworks"></a> [translated\_subnetworks](#output\_translated\_subnetworks) | Which subnets have their addresses translated. Exported so a reader can<br/>confirm from the plan that the workload subnet is not among them, which<br/>is the property the whole egress design rests on. |
<!-- END_TF_DOCS -->
