# Bootstrap — the state backend

Terraform cannot store its state in a bucket that Terraform has not created
yet. That circularity is the only reason this directory exists.

Each subdirectory is a **root module, applied by hand, with local state**.
It creates the bucket that every other unit will then use as its backend.
Nothing here is part of the Terragrunt run graph: `run --all` never touches
it, and a normal plan or apply cannot reach it.

```
bootstrap/
├── aws/   S3 bucket for state, locked natively (no DynamoDB table)
└── gcp/   GCS bucket for state, locked natively
```

## Running it

```bash
make infra-bootstrap CLOUD=aws BUCKET=shomer-tfstate REGION=eu-west-3
make infra-bootstrap CLOUD=gcp BUCKET=shomer-tfstate PROJECT=shomer LOCATION=EU
```

The apply prints a `remote_state_yaml` output. Paste it under
`remote_state:` in `../configs/<env>/config.yaml` and you are done —
`../root.hcl` reads that key and picks the backend from it. Until it is
there, the environment runs on local state.

The backend follows the environment's `provider:` unless the pasted yaml
overrides it, and the state path is derived as
`<environment>/services/<unit>`, so one bucket serves every environment.

One bucket serves every environment: the state key already carries the
environment name, so staging and production never collide. Separate
buckets per environment are a reasonable choice if you want a hard IAM
boundary between them — run the bootstrap twice with different names.

## Why there is no DynamoDB table

Terraform 1.10 locks S3 state with a lock file in the bucket itself
(`use_lockfile = true`). The table was the only reason the AWS bootstrap
ever needed a second resource, and `dynamodb_table` is deprecated as of
1.11. On Terraform below 1.10 you need the table back — add it here, and
set `dynamodb_table` instead of `use_lockfile` in the backend config.

## Moving the bootstrap's own state into the bucket

Optional, and worth doing: it removes the one `terraform.tfstate` file
that lives on somebody's laptop.

After the first apply, uncomment the `backend` block in the subdirectory's
`versions.tf` and run:

```bash
terraform init -migrate-state
```

Terraform copies the local state into the bucket it just created. Keep the
local file until you have confirmed the migration — `terraform state list`
against the new backend should return the same resources.

If you skip this, commit nothing: `terraform.tfstate` in this directory is
git-ignored, and losing it means the bucket becomes unmanaged rather than
lost. Re-importing is `terraform import aws_s3_bucket.state <name>`.

## What the tests cover

```bash
make infra-test M=bootstrap/aws
make infra-test M=bootstrap/gcp
```

Offline, through `mock_provider` — no credentials, no network, the same
contract as the modules under `../modules/`. They assert the properties
that make a bucket safe to hold state rather than terraform's ability to
create one: versioning on, public access impossible, encryption falling
back to a managed key and honouring a CMK when given, at least 30 days of
state history, TLS enforced (AWS), and `force_destroy` off.

Each of those has a failure mode that stays quiet until the day it
matters, which is why they are assertions and not comments.

## Permissions the bootstrap needs

More than the deploy identity, and only once. Run it with a human or a
dedicated bootstrap identity, not with the CI role.

- **AWS** — `s3:CreateBucket`, `s3:PutBucketVersioning`,
  `s3:PutEncryptionConfiguration`, `s3:PutBucketPublicAccessBlock`,
  `s3:PutBucketOwnershipControls`, `s3:PutLifecycleConfiguration`,
  `s3:PutBucketPolicy`, `s3:PutBucketTagging`. With a CMK, also
  `kms:DescribeKey` on it.
- **GCP** — `roles/storage.admin` on the project. With a CMEK, the bucket's
  service agent needs `roles/cloudkms.cryptoKeyEncrypterDecrypter` on the
  key, or bucket creation fails.

The identity CI uses afterwards needs far less: read and write objects
under the state prefix, and nothing at the bucket level.
