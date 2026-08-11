# vms-proxy-gcp

**Version:** 0.0.0

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

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
