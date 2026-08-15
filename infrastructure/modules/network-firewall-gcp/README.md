# network-firewall-gcp

**Version:** 0.1.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `network-firewall-gcp` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/network-firewall-gcp"
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
| [google_compute_firewall.deny_all_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.google_apis_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.health_checks](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.internal_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.proxy_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.tunnel_ingress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.workload_to_proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_internal_ranges"></a> [internal\_ranges](#input\_internal\_ranges) | Ranges treated as inside: the VPC, the pod range and the service range.<br/><br/>A cluster whose nodes cannot reach each other does not form, and the<br/>failure presents as a control plane problem rather than as a firewall<br/>one. | `list(string)` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | The VPC these rules apply to, from services/network/vpc. | `string` | n/a | yes |
| <a name="input_proxy_subnet_cidr"></a> [proxy\_subnet\_cidr](#input\_proxy\_subnet\_cidr) | The proxy subnet's range — the workload's only permitted destination<br/>outside its own subnet.<br/><br/>Written against the range rather than a tag on purpose: an egress rule<br/>to a target tag would let a workload reach anything that later acquires<br/>that tag, wherever it sits. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_google_apis_cidr"></a> [google\_apis\_cidr](#input\_google\_apis\_cidr) | Google's private API range. Must match the route in services/network/routes — the route makes it reachable, this makes it permitted, and both are required. | `string` | `"199.36.153.8/30"` | no |
| <a name="input_logging_enabled"></a> [logging\_enabled](#input\_logging\_enabled) | Log denied egress and tunnel connections.<br/><br/>The denies are the point: a refused outbound connection is the signal<br/>that something is trying to leave another way, and this is the only<br/>place that attempt is recorded. | `bool` | `true` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_proxy_egress_ports"></a> [proxy\_egress\_ports](#input\_proxy\_egress\_ports) | What the proxies themselves may reach on the internet.<br/><br/>Deliberately not "all": a proxy that can open any port is a tunnel out<br/>for anything that reaches it, which is most of the estate. Widen this<br/>when something genuinely needs another protocol, and know what. | `list(string)` | <pre>[<br/>  "80",<br/>  "443"<br/>]</pre> | no |
| <a name="input_proxy_port"></a> [proxy\_port](#input\_proxy\_port) | The port Squid listens on. The workload may reach the proxy subnet on this port and no other. | `number` | `3128` | no |
| <a name="input_proxy_tag"></a> [proxy\_tag](#input\_proxy\_tag) | Network tag on the egress proxies. Carrying it is what permits reaching the internet, so it belongs on the proxy fleet and nothing else. | `string` | `"egress-proxy"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |
| <a name="input_tunnel_ingress_enabled"></a> [tunnel\_ingress\_enabled](#input\_tunnel\_ingress\_enabled) | Allow the control-plane tunnel in. Off leaves no inbound path to any instance at all, including for an operator. | `bool` | `true` | no |
| <a name="input_workload_tag"></a> [workload\_tag](#input\_workload\_tag) | Network tag on the nodes pods run on. Carrying it permits reaching the proxy, and nothing beyond it. | `string` | `"workload"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_egress_is_denied_by_default"></a> [egress\_is\_denied\_by\_default](#output\_egress\_is\_denied\_by\_default) | Constant, and deliberately so. GCP's implied rules ALLOW egress, so the<br/>absence of firewall rules is an open network rather than a closed one.<br/>This output exists to make the presence of the deny rule visible to a<br/>reader of the plan, and to fail loudly if the resource is ever removed<br/>while callers still consume it. |
| <a name="output_proxy_tag"></a> [proxy\_tag](#output\_proxy\_tag) | The tag that permits reaching the internet. |
| <a name="output_workload_tag"></a> [workload\_tag](#output\_workload\_tag) | The tag that permits reaching the proxy, and nothing beyond it. |
<!-- END_TF_DOCS -->
