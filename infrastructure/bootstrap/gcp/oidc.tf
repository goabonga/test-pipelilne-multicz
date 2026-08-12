# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The identity CI uses to reach this project — Workload Identity Federation
# rather than a service account key.
#
# WHY NO KEY
#
# A service account key is a password with no expiry that has to be copied
# into GitHub. It survives the laptop it was made on, the person who made
# it, and every rotation policy written about it. WIF replaces it with an
# exchange: GitHub mints a short-lived token describing the running job,
# Google verifies its signature and the claims below, and hands back
# credentials that expire in an hour. Nothing secret is ever stored, which
# is why the outputs of this file are variables and not secrets.
#
# THE ATTRIBUTE CONDITION IS THE SECURITY BOUNDARY
#
# Without it, the pool trusts *every* GitHub Actions job on the platform —
# anyone's repository can mint a token from the same issuer. The condition
# pins the repository, and the bindings below pin further, to the specific
# job that may use each identity.
#
# Everything here is opt-in: with `github_repository` empty this file
# creates nothing and the bootstrap remains only a state bucket.

locals {
  oidc_enabled = var.github_repository != ""

  # GitHub's OIDC subject for a job that declares `environment: X` is
  # repo:<owner>/<repo>:environment:X. infra-plan declares
  # `environment: <env>-plan`, so the plan identity can be bound to an
  # exact subject.
  plan_subject = "repo:${var.github_repository}:environment:${var.plan_environment}"

  # infra-apply declares no environment — approval lives on the deploy PR
  # instead — so its subject is the far broader repo:<owner>/<repo>:
  # pull_request, shared by every pull_request-triggered job in the
  # repository. Binding write access to that would let any such job assume
  # it. job_workflow_ref names the workflow file and the ref it was loaded
  # from, so the binding below pins the identity to infra-apply.yml on main
  # and nothing else.
  apply_workflow_ref = "${var.github_repository}/${var.apply_workflow}@refs/heads/${var.apply_workflow_ref}"

  # Derived, not read back from the resources. A service account's email is
  # always <account_id>@<project>.iam.gserviceaccount.com, so nothing is
  # guessed — but the attribute is mocked in tests, where every account
  # would otherwise come back with the same placeholder and "does the plan
  # environment get the PLAN account?" would pass however the two were
  # wired.
  plan_email  = "${var.service_account_prefix}-plan@${var.project}.iam.gserviceaccount.com"
  apply_email = "${var.service_account_prefix}-apply@${var.project}.iam.gserviceaccount.com"
  plan_sa_id  = "projects/${var.project}/serviceAccounts/${local.plan_email}"
  apply_sa_id = "projects/${var.project}/serviceAccounts/${local.apply_email}"
}

resource "google_iam_workload_identity_pool" "github" {
  count = local.oidc_enabled ? 1 : 0

  project = var.project
  # A deleted pool is only soft-deleted and its id stays reserved for 30
  # days, so recreating one under the same name inside that window fails.
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = "GitHub Actions"
  description               = "Federated identities for ${var.github_repository}"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  # checkov:skip=CKV_GCP_125: The rule asks whether the subject is pinned to
  # one repository. It is — see attribute_condition below. The rule cannot
  # see it: it reads the unrendered source and validates the captured value
  # against a regex requiring a LITERAL slash between owner and repo. This
  # module takes owner/repo as one variable, so the source holds
  # "repo:${var.github_repository}:..." with no slash of its own, and the
  # match fails whatever the variable contains. Splitting the interface into
  # two variables to satisfy a regex would make the call sites worse and the
  # infrastructure no safer. tests/oidc.tftest.hcl asserts the rendered
  # condition instead, which is a stronger check than this one: it pins the
  # subject AND the workflow ref AND that both agree with the bindings.
  count = local.oidc_enabled ? 1 : 0

  project                            = var.project
  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_pool_provider_id
  display_name                       = "GitHub"

  # Only the claims named here can be used in bindings or conditions.
  # job_workflow_ref is what lets the apply identity be pinned to one
  # workflow file rather than to "some pull_request job".
  attribute_mapping = {
    "google.subject"         = "assertion.sub"
    "attribute.repository"   = "assertion.repository"
    "attribute.workflow_ref" = "assertion.job_workflow_ref"
  }

  # Refuses tokens from every other repository on GitHub before any binding
  # is consulted. Google rejects a provider that has no condition when the
  # issuer is GitHub, which is the platform telling you the same thing.
  #
  # The repository alone is not enough, though it is what most examples
  # stop at. It lets ANY job in this repository mint a pool credential — a
  # workflow added by a pull request included. Such a job still could not
  # impersonate either service account, because the bindings below name the
  # two callers exactly, but it would have crossed the first boundary and
  # every later mistake would be the only thing left. Naming the same two
  # callers here refuses it a step earlier.
  #
  # Two clauses because the two jobs are identified differently: infra-plan
  # declares an environment and so has a stable subject, while infra-apply
  # runs on a pull_request event whose subject is shared repository-wide,
  # leaving job_workflow_ref as the only claim that distinguishes it.
  # Written from the variables rather than from local.plan_subject and
  # local.apply_workflow_ref, which hold the same two strings. Static
  # analysers do not resolve locals: checkov sees "${local.plan_subject}",
  # finds no claim in it, and reports the provider as unconstrained —
  # indistinguishable from the real thing it is there to catch. A test
  # asserts these agree with the locals the bindings use, so the
  # duplication cannot drift.
  attribute_condition = "assertion.repository == \"${var.github_repository}\" && (assertion.sub == \"repo:${var.github_repository}:environment:${var.plan_environment}\" || assertion.job_workflow_ref == \"${var.github_repository}/${var.apply_workflow}@refs/heads/${var.apply_workflow_ref}\")"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# ── the two identities ──────────────────────────────────────────────────
#
# Split because they run under different rules. The plan identity runs on
# every push to main with no human involved; the apply identity runs only
# after a deploy PR is approved and merged. Giving the first the powers of
# the second would let an unreviewed job change the infrastructure, which
# is the whole reason the pipeline is split in two.

resource "google_service_account" "plan" {
  count = local.oidc_enabled ? 1 : 0

  project      = var.project
  account_id   = "${var.service_account_prefix}-plan"
  display_name = "CI plan (read-only)"
  description  = "Assumed by infra-plan through WIF. Reads infrastructure, writes only state."
}

resource "google_service_account" "apply" {
  count = local.oidc_enabled ? 1 : 0

  project      = var.project
  account_id   = "${var.service_account_prefix}-apply"
  display_name = "CI apply"
  description  = "Assumed by infra-apply through WIF after a deploy PR is merged."
}

# ── who may become them ─────────────────────────────────────────────────

resource "google_service_account_iam_member" "plan" {
  count = local.oidc_enabled ? 1 : 0

  service_account_id = local.plan_sa_id
  depends_on         = [google_service_account.plan]
  role               = "roles/iam.workloadIdentityUser"
  # An exact subject, not a principalSet over the repository: only the job
  # running under `environment: <plan_environment>` matches.
  member = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github[0].name}/subject/${local.plan_subject}"
}

resource "google_service_account_iam_member" "apply" {
  count = local.oidc_enabled ? 1 : 0

  service_account_id = local.apply_sa_id
  depends_on         = [google_service_account.apply]
  role               = "roles/iam.workloadIdentityUser"
  # Pinned to the workflow file rather than the subject, because the apply
  # job's subject is shared by every pull_request job in the repository.
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github[0].name}/attribute.workflow_ref/${local.apply_workflow_ref}"
}

# ── what they may do ────────────────────────────────────────────────────

resource "google_project_iam_member" "plan" {
  for_each = local.oidc_enabled ? toset(var.plan_roles) : toset([])

  project = var.project
  role    = each.value
  member  = "serviceAccount:${local.plan_email}"
}

resource "google_project_iam_member" "apply" {
  for_each = local.oidc_enabled ? toset(var.apply_roles) : toset([])

  project = var.project
  role    = each.value
  member  = "serviceAccount:${local.apply_email}"
}

# STATE IS THE EXCEPTION TO "PLAN IS READ-ONLY".
#
# A plan against a remote backend writes: it takes a lock before reading
# and releases it after. roles/viewer cannot do that, and the failure
# arrives as a permission error on an object nobody asked to create. Read
# access to infrastructure and write access to state are different
# questions and this is the one place they diverge.
resource "google_storage_bucket_iam_member" "plan_state" {
  count = local.oidc_enabled ? 1 : 0

  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.plan_email}"
}

resource "google_storage_bucket_iam_member" "apply_state" {
  count = local.oidc_enabled ? 1 : 0

  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${local.apply_email}"
}
