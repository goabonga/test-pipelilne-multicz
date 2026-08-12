# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline, through mock_provider — no credentials, no project, no network.
#
# These assert what decides WHO may federate into this project. Everything
# else about a service account is recoverable; a pool whose condition does
# not name the repository is a pool every GitHub repository can use, and it
# looks exactly like a working one until someone tries.

mock_provider "google" {}

variables {
  bucket            = "shomer-tfstate"
  project           = "goabonga-6d856"
  location          = "EU"
  github_repository = "goabonga/test-pipelilne-multicz"
}

run "disabled_by_default" {
  variables {
    github_repository = ""
  }

  # The bootstrap has to keep working as a plain state bucket, so that a
  # reader who wants only that is not forced into creating identities.
  assert {
    condition     = length(google_service_account.plan) == 0 && length(google_service_account.apply) == 0
    error_message = "an empty github_repository must create no service accounts"
  }

  assert {
    condition     = length(google_iam_workload_identity_pool.github) == 0
    error_message = "an empty github_repository must create no pool"
  }

  assert {
    condition     = length(output.github_variables) == 0
    error_message = "with no repository there is nothing to set on GitHub"
  }
}

run "provider_refuses_every_other_repository" {
  # THE single most important line in the whole file. A GitHub-issuer pool
  # without a condition on the repository trusts every Actions job on the
  # platform, and Google will happily create it.
  assert {
    condition = can(regex(
      "assertion.repository == \"goabonga/test-pipelilne-multicz\"",
      google_iam_workload_identity_pool_provider.github[0].attribute_condition
    ))
    error_message = "the provider must refuse tokens from any other repository"
  }

  # The repository alone would admit every job in it, including one added
  # by a pull request. The condition must name the two callers as well.
  assert {
    condition = can(regex(
      "assertion.sub == \"repo:goabonga/test-pipelilne-multicz:environment:staging-plan\"",
      google_iam_workload_identity_pool_provider.github[0].attribute_condition
    ))
    error_message = "the provider must admit the plan job by subject"
  }

  assert {
    condition = can(regex(
      "assertion.job_workflow_ref == \"[^\"]*infra-apply.yml@refs/heads/main\"",
      google_iam_workload_identity_pool_provider.github[0].attribute_condition
    ))
    error_message = "the provider must admit the apply job by workflow ref"
  }

  # The condition spells the two callers out from the variables, while the
  # bindings below use locals holding the same strings. That duplication is
  # deliberate — static analysers cannot resolve locals — so this is what
  # stops the two from drifting apart and admitting a caller no binding
  # serves, or worse, refusing one it does.
  assert {
    condition = can(regex(
      "assertion.sub == \"${local.plan_subject}\"",
      google_iam_workload_identity_pool_provider.github[0].attribute_condition
    ))
    error_message = "the condition's subject must be the one the plan binding uses"
  }

  assert {
    condition = can(regex(
      "assertion.job_workflow_ref == \"${local.apply_workflow_ref}\"",
      google_iam_workload_identity_pool_provider.github[0].attribute_condition
    ))
    error_message = "the condition's workflow ref must be the one the apply binding uses"
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github[0].oidc[0].issuer_uri == "https://token.actions.githubusercontent.com"
    error_message = "the issuer must be GitHub's"
  }

  # Unmapped claims cannot be used in a binding. Dropping workflow_ref here
  # would silently turn the apply binding below into a no-match.
  assert {
    condition = alltrue([
      for c in ["google.subject", "attribute.repository", "attribute.workflow_ref"] :
      contains(keys(google_iam_workload_identity_pool_provider.github[0].attribute_mapping), c)
    ])
    error_message = "subject, repository and workflow_ref must all be mapped"
  }
}

run "plan_identity_is_bound_to_one_exact_subject" {
  # `principal://.../subject/<sub>` matches one job. The tempting
  # alternative, principalSet over attribute.repository, matches every job
  # in the repository — including one added by a pull request.
  assert {
    condition = can(regex(
      "/subject/repo:goabonga/test-pipelilne-multicz:environment:staging-plan$",
      google_service_account_iam_member.plan[0].member
    ))
    error_message = "the plan account must be bound to the plan environment's exact subject"
  }

  assert {
    condition     = google_service_account_iam_member.plan[0].role == "roles/iam.workloadIdentityUser"
    error_message = "the binding must grant impersonation and nothing else"
  }

  assert {
    condition     = !can(regex("\\*", google_service_account_iam_member.plan[0].member))
    error_message = "no wildcard is allowed in the plan binding"
  }
}

run "apply_identity_is_bound_to_one_workflow_file" {
  # infra-apply declares no environment, so its subject is shared by every
  # pull_request job in the repository. The workflow ref is what makes this
  # account impersonable by one workflow rather than by any of them.
  assert {
    condition = can(regex(
      "attribute.workflow_ref/goabonga/test-pipelilne-multicz/\\.github/workflows/infra-apply\\.yml@refs/heads/main$",
      google_service_account_iam_member.apply[0].member
    ))
    error_message = "the apply account must be pinned to infra-apply.yml on main"
  }
}

run "plan_cannot_write_infrastructure_but_can_lock_state" {
  # The distinction this whole split exists for: read-only against the
  # project, read-write against the state bucket. A plan takes a lock
  # before it reads, so a genuinely read-only identity cannot plan.
  assert {
    condition     = contains(var.plan_roles, "roles/viewer") && length(var.plan_roles) == 1
    error_message = "the plan identity must default to read-only on the project"
  }

  assert {
    condition     = google_storage_bucket_iam_member.plan_state[0].role == "roles/storage.objectAdmin"
    error_message = "the plan identity must be able to write the lock object"
  }
}

run "apply_cannot_grant_itself_more" {
  # roles/editor is broad and deliberately not owner: editor cannot change
  # IAM, so this identity cannot widen its own access.
  assert {
    condition     = !contains(var.apply_roles, "roles/owner")
    error_message = "the apply identity must not default to owner"
  }
}

run "github_variables_name_both_environments" {
  # What the operator has to copy. Getting the plan and apply accounts the
  # wrong way round gives the unreviewed job write access, so the mapping
  # is asserted rather than described.
  assert {
    condition     = output.github_variables["staging-plan"].GCP_SERVICE_ACCOUNT == local.plan_email
    error_message = "the plan environment must receive the plan account"
  }

  assert {
    condition     = output.github_variables["staging"].GCP_SERVICE_ACCOUNT == local.apply_email
    error_message = "the apply environment must receive the apply account"
  }
}
