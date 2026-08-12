# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline, through mock_provider — no credentials, no account, no network.
#
# These assert the conditions that decide WHO may assume these roles.
# Everything else about an IAM role is recoverable; a trust policy missing
# one condition is a role the whole of GitHub can assume, and it looks
# exactly like a working one until someone tries.

mock_provider "aws" {}

variables {
  bucket            = "shomer-tfstate"
  region            = "eu-west-3"
  github_repository = "goabonga/test-pipelilne-multicz"
}

run "disabled_by_default" {
  variables {
    github_repository = ""
  }

  # The bootstrap has to keep working as a plain state bucket, so that a
  # reader who wants only that is not forced into creating identities.
  assert {
    condition     = length(aws_iam_role.plan) == 0 && length(aws_iam_role.apply) == 0
    error_message = "an empty github_repository must create no roles"
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 0
    error_message = "an empty github_repository must create no OIDC provider"
  }

  assert {
    condition     = length(output.github_variables) == 0
    error_message = "with no repository there is nothing to set on GitHub"
  }
}

run "provider_accepts_one_audience" {
  # A provider that accepts any audience accepts tokens minted for another
  # service entirely.
  assert {
    condition     = contains(aws_iam_openid_connect_provider.github[0].client_id_list, "sts.amazonaws.com") && length(aws_iam_openid_connect_provider.github[0].client_id_list) == 1
    error_message = "the provider must accept only the sts.amazonaws.com audience"
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github[0].url == "https://token.actions.githubusercontent.com"
    error_message = "the issuer must be GitHub's"
  }
}

run "existing_provider_is_reused_not_recreated" {
  variables {
    oidc_provider_arn = "arn:aws:iam::704421203038:oidc-provider/token.actions.githubusercontent.com"
  }

  # An account may hold only one provider per issuer. Creating a second
  # fails with EntityAlreadyExists, so pointing at an existing one has to
  # work — and the roles must trust the one that was passed in.
  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 0
    error_message = "a supplied provider ARN must not create a second provider"
  }

  assert {
    condition     = can(regex("704421203038:oidc-provider", local.plan_trust))
    error_message = "the roles must trust the supplied provider"
  }
}

run "plan_trust_is_pinned_to_this_repository_and_environment" {
  # The subject is the whole boundary. Without it the trust policy names
  # only the provider, which every GitHub repository shares.
  assert {
    condition = can(regex(
      "repo:goabonga/test-pipelilne-multicz:environment:production-plan",
      local.plan_trust
    ))
    error_message = "the plan role must be pinned to this repository and its plan environment"
  }

  assert {
    condition     = can(regex("sts\\.amazonaws\\.com", local.plan_trust))
    error_message = "the plan trust must require the sts audience"
  }

  # A wildcard anywhere in a subject condition widens it back out. The
  # common mistake is repo:owner/repo:* while believing it means "this
  # repository" — it also means every branch, every tag and every pull
  # request in it.
  assert {
    condition     = !can(regex("repo:[^\"]*\\*", local.plan_trust))
    error_message = "no wildcard is allowed in the plan role's subject condition"
  }
}

run "apply_trust_requires_both_subject_and_workflow" {
  # infra-apply declares no environment, so its subject is shared by every
  # pull_request job in the repository. The workflow ref is what makes this
  # role assumable by one workflow rather than by any of them.
  assert {
    condition = can(regex(
      "repo:goabonga/test-pipelilne-multicz:pull_request",
      local.apply_trust
    ))
    error_message = "the apply role must be pinned to this repository"
  }

  assert {
    condition = can(regex(
      "\\.github/workflows/infra-apply\\.yml@refs/heads/main",
      local.apply_trust
    ))
    error_message = "the apply role must be pinned to infra-apply.yml on main"
  }

  assert {
    condition     = can(regex("job_workflow_ref", local.apply_trust))
    error_message = "the apply role must condition on job_workflow_ref, not on the subject alone"
  }
}

run "plan_cannot_write_infrastructure_but_can_lock_state" {
  # The distinction this whole split exists for: read-only against the
  # account, read-write against the state bucket. A plan takes a lock
  # before it reads, so a genuinely read-only identity cannot plan.
  assert {
    condition     = contains(var.plan_policy_arns, "arn:aws:iam::aws:policy/ReadOnlyAccess") && length(var.plan_policy_arns) == 1
    error_message = "the plan role must default to read-only on infrastructure"
  }

  assert {
    condition = can(regex(
      "s3:PutObject", local.state_access
    )) && can(regex("s3:DeleteObject", local.state_access))
    error_message = "the plan role must be able to put and delete the lock object"
  }

  # Scoped to the state bucket. A state policy over "*" would hand the plan
  # identity every bucket in the account.
  assert {
    condition     = can(regex("arn:aws:s3:::shomer-tfstate", local.state_access))
    error_message = "state access must be scoped to the state bucket"
  }
}

run "apply_cannot_grant_itself_more" {
  # PowerUserAccess is everything except IAM. The moment IAM write lands
  # here, the apply path can escalate to administrator, and no reviewer of
  # a Terraform plan would see it.
  assert {
    condition     = !contains(var.apply_policy_arns, "arn:aws:iam::aws:policy/AdministratorAccess")
    error_message = "the apply role must not default to administrator"
  }
}

run "github_variables_name_both_environments" {
  # What the operator has to copy. Getting the plan and apply roles the
  # wrong way round gives the unreviewed job write access, so the mapping
  # is asserted rather than described.
  assert {
    condition     = output.github_variables["production-plan"].AWS_ROLE_ARN == aws_iam_role.plan[0].arn
    error_message = "the plan environment must receive the plan role"
  }

  assert {
    condition     = output.github_variables["production"].AWS_ROLE_ARN == aws_iam_role.apply[0].arn
    error_message = "the apply environment must receive the apply role"
  }

  assert {
    condition     = output.github_variables["production"].AWS_REGION == "eu-west-3"
    error_message = "the region must be the one the environment runs in"
  }
}
