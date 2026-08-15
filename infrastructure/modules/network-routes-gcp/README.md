# network-routes-gcp

**Version:** 0.1.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `network-routes-gcp` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/network-routes-gcp"
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
| [google_compute_route.google_apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route) | resource |
| [google_compute_route.proxy_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route) | resource |
| [google_compute_route.workload_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | The VPC these routes belong to, from services/network/vpc. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_google_apis_cidr"></a> [google\_apis\_cidr](#input\_google\_apis\_cidr) | Google's private API range. The default is private.googleapis.com,<br/>which serves most APIs over internal addresses.<br/><br/>199.36.153.4/30 is restricted.googleapis.com, which serves only APIs<br/>that support VPC Service Controls and refuses the rest — stricter, and<br/>worth the swap where an exfiltration boundary is required. | `string` | `"199.36.153.8/30"` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_proxy_ilb_address"></a> [proxy\_ilb\_address](#input\_proxy\_ilb\_address) | Forwarding rule of the proxy's internal load balancer.<br/><br/>Null until services/vms/proxy exists, and null means the workload nodes<br/>have NO default route at all — which is the intended resting state, not<br/>an outage. Pointing this at anything else in the meantime would open<br/>the path this design forbids, and it would work, which is why it would<br/>survive review. | `string` | `null` | no |
| <a name="input_proxy_tag"></a> [proxy\_tag](#input\_proxy\_tag) | Network tag identifying the egress proxies. The instances that carry it<br/>reach the internet directly; nothing else does.<br/><br/>It is a capability, not a label. Adding it to an instance grants that<br/>instance unmediated internet access, so it belongs on the proxy fleet<br/>and on nothing else. | `string` | `"egress-proxy"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |
| <a name="input_workload_tag"></a> [workload\_tag](#input\_workload\_tag) | Network tag identifying the nodes pods run on. Instances carrying it<br/>reach the internet only through the proxy, and only once the proxy<br/>exists. | `string` | `"workload"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_proxy_tag"></a> [proxy\_tag](#output\_proxy\_tag) | The tag that grants direct internet access. The proxy unit must put it on its instances and nothing else may carry it. |
| <a name="output_workload_has_egress"></a> [workload\_has\_egress](#output\_workload\_has\_egress) | Whether the workload nodes have a default route yet. False until the<br/>proxy exists — a fact worth being able to read from a plan rather than<br/>inferring from the absence of a resource. |
| <a name="output_workload_tag"></a> [workload\_tag](#output\_workload\_tag) | The tag that routes egress through the proxy. The node pool unit puts it on its nodes. |
<!-- END_TF_DOCS -->
