# bootstrap/gcp

**Version:** 0.1.0

<!--
  The line above is this component's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

The GCS bucket that holds every environment's Terraform state.

Applied **by hand, with local state**, because the thing it creates is the
remote backend — the circularity is the whole reason this exists. It is not
part of the Terragrunt run graph and CI never applies it.

```bash
make infra-bootstrap CLOUD=gcp BUCKET=shomer-tfstate PROJECT=shomer LOCATION=EU
```

The apply prints `remote_state_yaml`; paste it under `remote_state:` in
`../../configs/<env>/config.yaml`. See [`../README.md`](../README.md) for
the permissions this needs and the optional migration of its own state
into the bucket.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
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
| [google_storage_bucket.logs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket.state](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.logs_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket"></a> [bucket](#input\_bucket) | Name of the GCS bucket holding the Terraform state. Globally unique across all of GCS. | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Bucket location — a region (europe-west1) or a multi-region (EU). | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | GCP project that owns the bucket. | `string` | n/a | yes |
| <a name="input_access_log_retention_days"></a> [access\_log\_retention\_days](#input\_access\_log\_retention\_days) | How long GCS usage logs are kept. These record who read the state, so<br/>the retention is really "how far back an investigation can go" — a year<br/>is the usual floor for that. | `number` | `365` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Allow `terraform destroy` to delete a bucket that still holds objects.<br/>Left false on purpose: the objects here are the only record of what<br/>exists in the project. | `bool` | `false` | no |
| <a name="input_kms_key_name"></a> [kms\_key\_name](#input\_kms\_key\_name) | Customer-managed encryption key, as<br/>projects/<p>/locations/<l>/keyRings/<r>/cryptoKeys/<k>. Null uses<br/>Google-managed keys, which still encrypt at rest; a CMEK adds<br/>rotation you control and an audit trail of who decrypted state.<br/>State files contain every attribute of every resource, including<br/>values marked sensitive in the configuration.<br/><br/>The bucket's service agent needs roles/cloudkms.cryptoKeyEncrypter<br/>Decrypter on the key, or bucket creation fails. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels applied to the bucket. | `map(string)` | `{}` | no |
| <a name="input_noncurrent_version_retention_days"></a> [noncurrent\_version\_retention\_days](#input\_noncurrent\_version\_retention\_days) | How long superseded state generations are kept. Object versioning is<br/>what makes a corrupted state recoverable, so this is the length of the<br/>undo history. | `number` | `90` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket"></a> [bucket](#output\_bucket) | Name of the state bucket. |
| <a name="output_location"></a> [location](#output\_location) | Location the state bucket lives in. |
| <a name="output_remote_state_yaml"></a> [remote\_state\_yaml](#output\_remote\_state\_yaml) | The remote\_state block to paste into configs/<env>/config.yaml. |
<!-- END_TF_DOCS -->
