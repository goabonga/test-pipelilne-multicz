# bootstrap/aws

**Version:** 0.0.0

<!--
  The line above is this component's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

The S3 bucket that holds every environment's Terraform state.

Applied **by hand, with local state**, because the thing it creates is the
remote backend — the circularity is the whole reason this exists. It is not
part of the Terragrunt run graph and CI never applies it.

```bash
make infra-bootstrap CLOUD=aws BUCKET=shomer-tfstate REGION=eu-west-3
```

The apply prints `remote_state_yaml`; paste it under `remote_state:` in
`../../configs/<env>/config.yaml`. See [`../README.md`](../README.md) for
the permissions this needs, the optional migration of its own state into
the bucket, and why there is no DynamoDB lock table.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
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
| [aws_s3_bucket.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_ownership_controls.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_ownership_controls.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.logs_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.tls_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket"></a> [bucket](#input\_bucket) | Name of the S3 bucket holding the Terraform state. Globally unique across all of AWS. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the bucket lives in. | `string` | n/a | yes |
| <a name="input_access_log_retention_days"></a> [access\_log\_retention\_days](#input\_access\_log\_retention\_days) | How long S3 server access logs are kept. These record who read the<br/>state, so the retention is really "how far back an investigation can<br/>go" — a year is the usual floor for that. | `number` | `365` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Allow `terraform destroy` to delete a bucket that still holds objects.<br/>Left false on purpose: the objects here are the only record of what<br/>exists in the account. | `bool` | `false` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Customer-managed KMS key for bucket encryption. Null uses SSE-S3<br/>(AES256), which is free and still encrypts at rest; a CMK adds key<br/>rotation you control and an audit trail of who decrypted state.<br/>State files contain every attribute of every resource, including<br/>values marked sensitive in the configuration. | `string` | `null` | no |
| <a name="input_noncurrent_version_retention_days"></a> [noncurrent\_version\_retention\_days](#input\_noncurrent\_version\_retention\_days) | How long superseded state versions are kept. Versioning is what makes<br/>a corrupted or truncated state recoverable, so this is the length of<br/>the undo history, not housekeeping. | `number` | `90` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the bucket. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket"></a> [bucket](#output\_bucket) | Name of the state bucket. |
| <a name="output_region"></a> [region](#output\_region) | Region the state bucket lives in. |
| <a name="output_remote_state_yaml"></a> [remote\_state\_yaml](#output\_remote\_state\_yaml) | The remote\_state block to paste into configs/<env>/config.yaml. |
<!-- END_TF_DOCS -->
