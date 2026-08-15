# vms-proxy-aws

**Version:** 0.1.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `vms-proxy-aws` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/vms-proxy-aws"
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
| [aws_autoscaling_group.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_launch_template.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allowed_domains"></a> [allowed\_domains](#input\_allowed\_domains) | Destinations the proxy will forward to. THE POLICY, and identical in<br/>shape to the GCP module so that one cloud cannot end up more permissive<br/>than the other by accident. | `list(string)` | n/a | yes |
| <a name="input_client_cidrs"></a> [client\_cidrs](#input\_client\_cidrs) | Ranges permitted to use the proxy — the workload subnets. The security group says the same thing at the packet layer. | `list(string)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_image_id"></a> [image\_id](#input\_image\_id) | AMI. Debian, because the user data installs squid from apt. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | The proxy group from services/network/firewall.<br/><br/>It is the capability: that group is the only one permitted to reach the<br/>internet, so membership is what grants this fleet egress. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | The egress subnets these instances sit in — the only ones with a way out. | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The VPC, from services/network/vpc. | `string` | n/a | yes |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Refuse to delete the load balancer.<br/><br/>On by default: this one address is what every workload in the estate<br/>sends its traffic to, so deleting it is an outage for everything at<br/>once — and it is the kind of resource that gets caught up in a cleanup<br/>aimed at something else. Turn it off deliberately when tearing an<br/>environment down. | `bool` | `true` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Root volume. Nothing is cached, so this holds the system and the logs until they ship. | `number` | `20` | no |
| <a name="input_ha"></a> [ha](#input\_ha) | Run more than one instance. Not about load — about a restart or a zone failure not being an outage for everything behind the proxy. | `bool` | `false` | no |
| <a name="input_ha_size"></a> [ha\_size](#input\_ha\_size) | Fleet size when ha is on. | `number` | `2` | no |
| <a name="input_instance_profile"></a> [instance\_profile](#input\_instance\_profile) | Instance profile for Session Manager access. Null leaves the fleet<br/>unreachable by an operator — which is a legitimate state, and not the<br/>one you want when the proxy is the thing that has failed. | `string` | `null` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | A proxy is network-bound rather than CPU-bound; the fleet scales by count. | `string` | `"t3.small"` | no |
| <a name="input_port"></a> [port](#input\_port) | The port Squid listens on. Must match the security group rule, all of which read it from the same config key. | `number` | `3128` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_allowed_domains"></a> [allowed\_domains](#output\_allowed\_domains) | The destinations this environment may reach. Exported so the policy is readable from a plan rather than only from a rendered file on a disk. |
| <a name="output_nlb_arn"></a> [nlb\_arn](#output\_nlb\_arn) | The internal load balancer in front of the fleet. |
| <a name="output_nlb_dns_name"></a> [nlb\_dns\_name](#output\_nlb\_dns\_name) | What workloads point their proxy setting at. |
| <a name="output_size"></a> [size](#output\_size) | How many proxies are running. One is a single point of failure for the whole estate's egress; ha makes it more. |
<!-- END_TF_DOCS -->
