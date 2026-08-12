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
| [google_iam_workload_identity_pool.github](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.github](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_project_iam_member.apply](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.plan](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.apply](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.plan](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.apply](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_service_account_iam_member.plan](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_storage_bucket.logs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket.state](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.apply_state](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_iam_member.logs_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_iam_member.plan_state](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket"></a> [bucket](#input\_bucket) | Name of the GCS bucket holding the Terraform state. Globally unique across all of GCS. | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Bucket location — a region (europe-west1) or a multi-region (EU). | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | GCP project that owns the bucket. | `string` | n/a | yes |
| <a name="input_access_log_retention_days"></a> [access\_log\_retention\_days](#input\_access\_log\_retention\_days) | How long GCS usage logs are kept. These record who read the state, so<br/>the retention is really "how far back an investigation can go" — a year<br/>is the usual floor for that. | `number` | `365` | no |
| <a name="input_apply_roles"></a> [apply\_roles](#input\_apply\_roles) | Project roles for the apply identity.<br/><br/>roles/editor is a STARTING POINT, not a recommendation. It is broad<br/>enough to create everything the modules under ../../modules/ will<br/>declare and too broad to leave in place once they exist — narrow it to<br/>the services actually used (compute, container, dns) when they do.<br/><br/>It deliberately excludes roles/owner: editor cannot change IAM, so this<br/>identity cannot grant itself more than it has. | `list(string)` | <pre>[<br/>  "roles/editor"<br/>]</pre> | no |
| <a name="input_apply_workflow"></a> [apply\_workflow](#input\_apply\_workflow) | Workflow file the apply identity is pinned to, repo-relative. | `string` | `".github/workflows/infra-apply.yml"` | no |
| <a name="input_apply_workflow_ref"></a> [apply\_workflow\_ref](#input\_apply\_workflow\_ref) | Branch the apply workflow must be loaded from. Pinning this is what<br/>stops a workflow edited on a side branch from assuming the apply<br/>identity. | `string` | `"main"` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Allow `terraform destroy` to delete a bucket that still holds objects.<br/>Left false on purpose: the objects here are the only record of what<br/>exists in the project. | `bool` | `false` | no |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | owner/repo allowed to federate into this project, e.g.<br/>"goabonga/test-pipelilne-multicz". Becomes the provider's attribute<br/>condition, which is what stops every other repository on GitHub from<br/>minting a usable token. Empty disables the whole OIDC section. | `string` | `""` | no |
| <a name="input_kms_key_name"></a> [kms\_key\_name](#input\_kms\_key\_name) | Customer-managed encryption key, as<br/>projects/<p>/locations/<l>/keyRings/<r>/cryptoKeys/<k>. Null uses<br/>Google-managed keys, which still encrypt at rest; a CMEK adds<br/>rotation you control and an audit trail of who decrypted state.<br/>State files contain every attribute of every resource, including<br/>values marked sensitive in the configuration.<br/><br/>The bucket's service agent needs roles/cloudkms.cryptoKeyEncrypter<br/>Decrypter on the key, or bucket creation fails. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels applied to the bucket. | `map(string)` | `{}` | no |
| <a name="input_noncurrent_version_retention_days"></a> [noncurrent\_version\_retention\_days](#input\_noncurrent\_version\_retention\_days) | How long superseded state generations are kept. Object versioning is<br/>what makes a corrupted state recoverable, so this is the length of the<br/>undo history. | `number` | `90` | no |
| <a name="input_plan_environment"></a> [plan\_environment](#input\_plan\_environment) | The GitHub environment infra-plan declares for this cloud's<br/>environment. It appears verbatim in the OIDC subject, so it must match<br/>`environment:` in infra-plan.yml — a mismatch fails the exchange with<br/>an unauthorized error naming no claim. | `string` | `"staging-plan"` | no |
| <a name="input_plan_roles"></a> [plan\_roles](#input\_plan\_roles) | Project roles for the plan identity. Read-only on infrastructure —<br/>write access to state is granted separately on the bucket, because a<br/>plan against a remote backend must take a lock. | `list(string)` | <pre>[<br/>  "roles/viewer"<br/>]</pre> | no |
| <a name="input_service_account_prefix"></a> [service\_account\_prefix](#input\_service\_account\_prefix) | Prefix for the two service accounts, suffixed -plan and -apply. | `string` | `"shomer-ci"` | no |
| <a name="input_workload_identity_pool_id"></a> [workload\_identity\_pool\_id](#input\_workload\_identity\_pool\_id) | Pool id. A deleted pool reserves its id for 30 days, so reuse rather than recreate. | `string` | `"github"` | no |
| <a name="input_workload_identity_pool_provider_id"></a> [workload\_identity\_pool\_provider\_id](#input\_workload\_identity\_pool\_provider\_id) | Provider id inside the pool. | `string` | `"github"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket"></a> [bucket](#output\_bucket) | Name of the state bucket. |
| <a name="output_github_variables"></a> [github\_variables](#output\_github\_variables) | GitHub environment variables, keyed by environment name. |
| <a name="output_location"></a> [location](#output\_location) | Location the state bucket lives in. |
| <a name="output_remote_state_yaml"></a> [remote\_state\_yaml](#output\_remote\_state\_yaml) | The remote\_state block to paste into configs/<env>/config.yaml. |
<!-- END_TF_DOCS -->
