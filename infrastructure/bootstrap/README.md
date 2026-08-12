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

## The CI identity

```bash
make infra-oidc CLOUD=gcp    # or aws; DRY_RUN=1 to plan only
```

Run it after the bucket exists, with the same elevated credentials. It
creates the identity CI assumes and then sets the GitHub variables that
point at it, so there is nothing to copy by hand.

**Nothing it produces is a secret.** A role ARN, a workload identity
provider path and a service account email are identifiers. They are
useless without a token GitHub will only mint for this repository, which
is why they are set as *variables* and printed in the open. There is no
key to store, rotate or leak — that is the entire point of federation, and
it is why the alternative (a service account key or an access key pasted
into a secret) is worse in a way that never announces itself.

Which environment each cloud serves is not configured here. It is read
from `provider:` in `../configs/<env>/config.yaml` — the same key that
picks the module, the generated provider block and the backend — so this
cannot disagree with the pipeline.

### What gets created

| | GCP | AWS |
|---|---|---|
| trust | workload identity pool + provider | OIDC provider for GitHub |
| plan | `shomer-ci-plan` service account | `shomer-ci-plan` role |
| apply | `shomer-ci-apply` service account | `shomer-ci-apply` role |
| variables set | `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT` | `AWS_ROLE_ARN`, `AWS_REGION` |

### Two identities, not one

The plan identity runs on every push to main with no human involved. The
apply identity runs only after a deploy PR has been approved and merged.
Merging them would let an ungated job change infrastructure, which is the
reason the pipeline is split in two in the first place.

They are pinned differently because the two jobs are identifiable
differently. `infra-plan` declares `environment: <env>-plan`, so its OIDC
subject is stable and the identity is bound to that exact subject.
`infra-apply` declares no environment — approval lives on the deploy PR —
so its subject is `repo:<owner>/<repo>:pull_request`, shared by every
pull_request job in the repository. Binding write access to that alone
would let any of them assume it, so the apply identity is pinned on
`job_workflow_ref` instead: the workflow file, on `main`, and nothing else.

### Plan is read-only, except on state

A plan against a remote backend **writes**: it takes a lock before reading
and releases it after. A genuinely read-only identity cannot plan. So both
identities get object-level write on the state bucket, and only the apply
one can change infrastructure. If you tighten these, keep that split — the
failure otherwise arrives as a permission error on an object nobody asked
to create.

### The permissions are a starting point

`roles/editor` on GCP and `PowerUserAccess` on AWS are wide enough to
create everything the modules under `../modules/` will declare, and too
wide to leave in place once they exist. Narrow them to the services
actually used when the modules are written.

Both deliberately exclude IAM, so neither identity can widen its own
access. That also means neither can create the node and service roles a
Kubernetes cluster needs: when you get there, add narrowly scoped IAM
permissions rather than widening these, and know that doing so hands the
apply path a route to privilege escalation that no reviewer of a Terraform
plan would see.

## Why there is no DynamoDB table

Terraform 1.10 locks S3 state with a lock file in the bucket itself
(`use_lockfile = true`). The table was the only reason the AWS bootstrap
ever needed a second resource, and `dynamodb_table` is deprecated as of
1.11. On Terraform below 1.10 you need the table back — add it here, and
set `dynamodb_table` instead of `use_lockfile` in the backend config.

## Moving the bootstrap's own state into the bucket

This is the ONLY state that needs migrating, and it is optional.

The units under `services/` need nothing: their state has only ever lived
in `.terragrunt-cache`, which is thrown away, so pasting `remote_state:`
into the environment config starts them on the bucket with nothing lost.
There is no migration because there was never anything to migrate.

The bootstrap is the exception — it holds the buckets themselves, in a
`terraform.tfstate` on somebody's laptop. Losing that file does not lose
the buckets, it makes them unmanaged, and re-importing is manual.

After the first apply, uncomment the `backend` block in the subdirectory's
`versions.tf` — it is at the bottom, with the values to match — and run:

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
