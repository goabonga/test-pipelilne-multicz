# vms-proxy-gcp

**Version:** 0.1.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `vms-proxy-gcp` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/vms-proxy-gcp"
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
| [google_compute_forwarding_rule.proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule) | resource |
| [google_compute_health_check.proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check) | resource |
| [google_compute_instance_template.proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_template) | resource |
| [google_compute_region_backend_service.proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_instance_group_manager.proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager) | resource |
| [google_service_account.proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allowed_domains"></a> [allowed\_domains](#input\_allowed\_domains) | Destinations the proxy will forward to. THE POLICY.<br/><br/>No default, deliberately. A permissive one would make this fleet a<br/>router with extra steps — satisfying "traffic leaves through one place"<br/>while giving up the reason that was worth arranging. Naming what the<br/>estate is allowed to reach is the point of having a proxy at all.<br/><br/>Domains rather than addresses: an address list rots silently as<br/>services move, and the failure is a timeout with nothing to say a<br/>policy caused it. | `list(string)` | n/a | yes |
| <a name="input_client_cidrs"></a> [client\_cidrs](#input\_client\_cidrs) | Ranges permitted to use the proxy — the workload subnets.<br/><br/>The firewall says the same thing at the packet layer. Saying it twice<br/>is deliberate: a mistake in either one is then not enough on its own to<br/>open the path. | `list(string)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_network_id"></a> [network\_id](#input\_network\_id) | The VPC, from services/network/vpc. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | The egress subnet these instances sit in — the only one with a way out. | `string` | n/a | yes |
| <a name="input_zones"></a> [zones](#input\_zones) | Zones the fleet is spread across. One in staging, three in production. | `list(string)` | n/a | yes |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Boot disk. Nothing is cached, so this holds the system and the logs until they ship. | `number` | `20` | no |
| <a name="input_ha"></a> [ha](#input\_ha) | Run more than one instance.<br/><br/>Not about load — one instance serves the traffic — but about a restart<br/>or a zone failure not being an outage for everything behind the proxy,<br/>which in this design is everything. | `bool` | `false` | no |
| <a name="input_ha_size"></a> [ha\_size](#input\_ha\_size) | Fleet size when ha is on. | `number` | `2` | no |
| <a name="input_image"></a> [image](#input\_image) | Boot image. Debian because the startup script installs squid from apt. | `string` | `"debian-cloud/debian-12"` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | Instance size. A proxy is network-bound rather than CPU-bound; the smallest sizes are usually enough and the fleet scales by count. | `string` | `"e2-small"` | no |
| <a name="input_port"></a> [port](#input\_port) | The port Squid listens on. Must match the firewall rule and the route, all three of which read it from the same config key. | `number` | `3128` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_proxy_tag"></a> [proxy\_tag](#input\_proxy\_tag) | Network tag placed on these instances.<br/><br/>It is a capability, not a label: services/network/routes and<br/>services/network/firewall both key on it, so carrying it is what grants<br/>an instance the internet. | `string` | `"egress-proxy"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_allowed_domains"></a> [allowed\_domains](#output\_allowed\_domains) | The destinations this environment may reach. Exported so the policy is readable from a plan rather than only from a rendered config on a disk. |
| <a name="output_ilb_address"></a> [ilb\_address](#output\_ilb\_address) | The address workloads send their traffic to. |
| <a name="output_ilb_forwarding_rule"></a> [ilb\_forwarding\_rule](#output\_ilb\_forwarding\_rule) | What services/network/routes points the workload's default route at.<br/><br/>Until this exists that route does not, and the workload has no way off<br/>the network at all — which is the intended resting state rather than an<br/>outage. |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | The fleet's identity. Holds no project roles, and should keep holding none. |
| <a name="output_size"></a> [size](#output\_size) | How many proxies are running. One is a single point of failure for the whole estate's egress; ha makes it more. |
<!-- END_TF_DOCS -->
