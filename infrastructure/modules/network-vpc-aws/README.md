# network-vpc-aws

**Version:** 0.1.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `network-vpc-aws` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/network-vpc-aws"
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
| [aws_cloudwatch_log_group.flow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cidr"></a> [cidr](#input\_cidr) | The VPC's address range, from `network.cidr` in the environment config.<br/><br/>It has to hold every subnet, the pod range and the service range, and<br/>it cannot be changed afterwards — resizing a VPC means rebuilding it. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_allow_public_cidr"></a> [allow\_public\_cidr](#input\_allow\_public\_cidr) | Permit a VPC CIDR outside RFC1918. Off, because everything in this<br/>design is private and a public range would become routable the moment<br/>a gateway appeared, with nothing downstream noticing. | `bool` | `false` | no |
| <a name="input_flow_logs_enabled"></a> [flow\_logs\_enabled](#input\_flow\_logs\_enabled) | Record traffic the VPC refused. In a network whose whole design is<br/>"nothing leaves except through the proxy", this is the only thing that<br/>can say whether something found another way. | `bool` | `true` | no |
| <a name="input_flow_logs_kms_key_arn"></a> [flow\_logs\_kms\_key\_arn](#input\_flow\_logs\_kms\_key\_arn) | Customer-managed key for the log group. Null uses the CloudWatch<br/>service key, which still encrypts at rest but leaves the audit trail of<br/>who read the logs in AWS's hands rather than yours. | `string` | `null` | no |
| <a name="input_flow_logs_retention_days"></a> [flow\_logs\_retention\_days](#input\_flow\_logs\_retention\_days) | How long flow logs are kept.<br/><br/>A year rather than the operationally comfortable ninety days. An<br/>intrusion is typically found months after it happened, and a ninety-day<br/>window means the evidence of how something got out has already expired<br/>by the time anyone goes looking — which is the one question flow logs<br/>exist to answer. | `number` | `365` | no |
| <a name="input_flow_logs_traffic_type"></a> [flow\_logs\_traffic\_type](#input\_flow\_logs\_traffic\_type) | ACCEPT, REJECT or ALL. REJECT by default: accepted traffic inside a<br/>private network is the normal case, and its volume is the usual reason<br/>flow logs get switched off entirely. | `string` | `"REJECT"` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | VPC ARN, for policies that scope to this network. |
| <a name="output_cidr"></a> [cidr](#output\_cidr) | The range that was actually created, not the one that was asked for. |
| <a name="output_default_security_group_id"></a> [default\_security\_group\_id](#output\_default\_security\_group\_id) | The emptied default group. Exported so a reader can confirm what it is<br/>attached to, NOT so anything can be attached to it — it permits nothing<br/>in either direction by design. |
| <a name="output_id"></a> [id](#output\_id) | VPC id, consumed by every unit that puts something in it. |
<!-- END_TF_DOCS -->
