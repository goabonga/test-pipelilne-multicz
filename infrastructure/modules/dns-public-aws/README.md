# dns-public-aws

**Version:** 0.2.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `dns-public-aws` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/dns-public-aws"
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
| [aws_route53_hosted_zone_dnssec.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_hosted_zone_dnssec) | resource |
| [aws_route53_key_signing_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_key_signing_key) | resource |
| [aws_route53_query_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_query_log) | resource |
| [aws_route53_record.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_domain"></a> [domain](#input\_domain) | The zone's domain, without a trailing dot. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_dnssec_key_arn"></a> [dnssec\_key\_arn](#input\_dnssec\_key\_arn) | Customer-managed KMS key that signs the zone. Null leaves it unsigned.<br/><br/>Route 53 is a global service and signs only from us-east-1, so the key<br/>must live there whatever region the rest of the environment runs in —<br/>and the apply identity cannot create it, for the same reason it cannot<br/>create IAM roles. That is an ordering constraint, not a preference,<br/>which is why this is opt-in rather than defaulted on. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_query_log_group_arn"></a> [query\_log\_group\_arn](#input\_query\_log\_group\_arn) | CloudWatch log group receiving this zone's DNS queries. Null logs<br/>nothing.<br/><br/>It must live in us-east-1 whatever region the rest of the environment<br/>runs in — Route 53 is global and writes query logs only from there —<br/>and it needs a resource policy the apply identity cannot create, which<br/>is why this is opt-in rather than defaulted on.<br/><br/>Worth enabling once it exists: on a public zone the queries are the<br/>only record of who is probing names nobody advertised. | `string` | `null` | no |
| <a name="input_records"></a> [records](#input\_records) | Records in the zone, keyed by name relative to the domain.<br/><br/>Only the load balancer belongs here. Everything else in this<br/>infrastructure is private and must not appear in a zone the internet<br/>reads. | <pre>map(object({<br/>    type   = string<br/>    ttl    = optional(number, 300)<br/>    values = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_domain"></a> [domain](#output\_domain) | The domain this zone serves. |
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | The servers to delegate to at the registrar.<br/><br/>Until that delegation exists the zone is authoritative for nothing, and<br/>every record in it is correct and unreachable — which looks exactly<br/>like a propagation delay for as long as anyone is willing to wait. |
| <a name="output_signed"></a> [signed](#output\_signed) | Whether the zone is signed. Readable from a plan rather than inferred from the presence of a key ARN. |
| <a name="output_visibility"></a> [visibility](#output\_visibility) | Constant, and stated so a plan says it out loud. Only production should have one at all. |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | Zone id. |
<!-- END_TF_DOCS -->
