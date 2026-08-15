# dns-public-gcp

**Version:** 0.2.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `dns-public-gcp` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/dns-public-gcp"
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
| [google_dns_managed_zone.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_dns_record_set.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_domain"></a> [domain](#input\_domain) | The zone's domain, without a trailing dot. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_dnssec"></a> [dnssec](#input\_dnssec) | Sign the zone.<br/><br/>On by default: this zone serves the one public entry point to an<br/>otherwise private estate, which makes it worth being unable to forge.<br/>Turning it off is a decision about a specific registrar limitation, not<br/>a default to inherit. | `bool` | `true` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_records"></a> [records](#input\_records) | Records in the zone, keyed by name relative to the domain.<br/><br/>Only the load balancer belongs here. Everything else in this<br/>infrastructure is private and must not appear in a zone the internet<br/>reads. | <pre>map(object({<br/>    type   = string<br/>    ttl    = optional(number, 300)<br/>    values = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_domain"></a> [domain](#output\_domain) | The domain this zone serves. |
| <a name="output_name"></a> [name](#output\_name) | Zone name. |
| <a name="output_name_servers"></a> [name\_servers](#output\_name\_servers) | The servers to delegate to at the registrar.<br/><br/>Until that delegation exists the zone is authoritative for nothing, and<br/>every record in it is correct and unreachable — which looks exactly<br/>like a propagation delay for as long as anyone is willing to wait. |
| <a name="output_visibility"></a> [visibility](#output\_visibility) | Constant, and stated so a plan answers 'is this zone reachable from outside?' out loud. Only production should have one at all. |
<!-- END_TF_DOCS -->
