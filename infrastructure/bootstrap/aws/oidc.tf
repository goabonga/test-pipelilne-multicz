# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# The identity CI uses to reach this account — an OIDC trust rather than an
# access key.
#
# WHY NO ACCESS KEY
#
# An access key is a password with no expiry that has to be copied into
# GitHub. It survives the laptop it was made on, the person who made it,
# and every rotation policy written about it. OIDC replaces it with an
# exchange: GitHub mints a short-lived token describing the running job,
# STS verifies its signature and the conditions below, and hands back
# credentials that expire in an hour. Nothing secret is ever stored, which
# is why the outputs of this file are variables and not secrets.
#
# THE TRUST CONDITIONS ARE THE SECURITY BOUNDARY
#
# A trust policy naming only the provider trusts *every* GitHub Actions job
# on the platform — anyone's repository can mint a token from the same
# issuer. The `sub` and `aud` conditions below are what narrow it to this
# repository and to the specific job that may assume each role. A role
# without them is a public role.
#
# Everything here is opt-in: with `github_repository` empty this file
# creates nothing and the bootstrap remains only a state bucket.

locals {
  oidc_enabled = var.github_repository != ""

  # AN ACCOUNT MAY HOLD ONLY ONE PROVIDER PER ISSUER URL. A second apply
  # for the same issuer fails with EntityAlreadyExists, which is why this
  # can be pointed at an existing one instead of always creating.
  create_provider = local.oidc_enabled && var.oidc_provider_arn == ""
  provider_arn = local.oidc_enabled ? (
    local.create_provider ? aws_iam_openid_connect_provider.github[0].arn : var.oidc_provider_arn
  ) : ""

  # GitHub's OIDC subject for a job that declares `environment: X` is
  # repo:<owner>/<repo>:environment:X. infra-plan declares
  # `environment: <env>-plan`, so the plan role can be pinned to an exact
  # subject.
  plan_subject = "repo:${var.github_repository}:environment:${var.plan_environment}"

  # infra-apply declares no environment — approval lives on the deploy PR
  # instead — so its subject is the far broader repo:<owner>/<repo>:
  # pull_request, shared by every pull_request-triggered job in the
  # repository. Pinning write access to that alone would let any such job
  # assume it, so the apply role also conditions on job_workflow_ref, which
  # names the workflow file and the ref it was loaded from.
  apply_workflow_ref = "${var.github_repository}/${var.apply_workflow}@refs/heads/${var.apply_workflow_ref}"

  # var.bucket rather than aws_s3_bucket.state.id: the two are the same
  # string — the resource sets its name from this variable — but the
  # attribute is mocked in tests, so building the ARN from it would make
  # "is state access scoped to the state bucket?" unanswerable offline.
  state_arn = "arn:aws:s3:::${var.bucket}"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = local.create_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  # The only audience google-github-actions and configure-aws-credentials
  # request. Narrowing it here means a token minted for any other audience
  # is rejected before a role is even considered.
  client_id_list = ["sts.amazonaws.com"]

  # No thumbprint_list. IAM has verified GitHub's certificate chain against
  # its own trust store since 2023 and ignores the value; the fixed
  # thumbprints still copied between tutorials were a maintenance burden
  # that broke on every certificate rotation.
  thumbprint_list = []

  tags = var.tags
}

# ── the two roles ───────────────────────────────────────────────────────
#
# Split because they run under different rules. The plan role runs on every
# push to main with no human involved; the apply role runs only after a
# deploy PR is approved and merged. Giving the first the powers of the
# second would let an unreviewed job change the infrastructure, which is
# the whole reason the pipeline is split in two.

# The policies are jsonencode() rather than aws_iam_policy_document.
# mock_provider mocks every data source in the provider, so a policy built
# from one is a mock string in tests — the conditions below could be
# deleted and the tests would still pass. Rendering them here means the
# tests read the same JSON that IAM will.
locals {
  trust_base = {
    Version = "2012-10-17"
  }

  plan_trust = jsonencode(merge(local.trust_base, {
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = local.provider_arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = local.plan_subject
        }
      }
    }]
  }))

  apply_trust = jsonencode(merge(local.trust_base, {
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = local.provider_arn }
      # Both conditions, not either: the subject alone is shared across the
      # repository's pull_request jobs, and the workflow ref alone would
      # match the workflow running under any trigger.
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud"              = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub"              = "repo:${var.github_repository}:pull_request"
          "token.actions.githubusercontent.com:job_workflow_ref" = local.apply_workflow_ref
        }
      }
    }]
  }))

  # STATE IS THE EXCEPTION TO "PLAN IS READ-ONLY".
  #
  # A plan against a remote backend writes: with use_lockfile it puts a
  # .tflock object before reading and deletes it after. ReadOnlyAccess
  # cannot do that, and the failure arrives as AccessDenied on an object
  # nobody asked to create. Read access to infrastructure and write access
  # to state are different questions and this is the one place they
  # diverge.
  state_access = jsonencode(merge(local.trust_base, {
    Statement = concat(
      [
        {
          Effect   = "Allow"
          Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
          Resource = local.state_arn
        },
        {
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
          Resource = "${local.state_arn}/*"
        },
      ],
      var.kms_key_arn == null ? [] : [{
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      }],
    )
  }))
}

resource "aws_iam_role" "plan" {
  count = local.oidc_enabled ? 1 : 0

  name               = "${var.role_prefix}-plan"
  description        = "Assumed by infra-plan through OIDC. Reads infrastructure, writes only state."
  assume_role_policy = local.plan_trust
  # An hour is longer than any plan takes and shorter than a working day.
  max_session_duration = 3600
  tags                 = var.tags
}

resource "aws_iam_role" "apply" {
  count = local.oidc_enabled ? 1 : 0

  name                 = "${var.role_prefix}-apply"
  description          = "Assumed by infra-apply through OIDC after a deploy PR is merged."
  assume_role_policy   = local.apply_trust
  max_session_duration = 3600
  tags                 = var.tags
}

# ── what they may do ────────────────────────────────────────────────────

resource "aws_iam_role_policy_attachment" "plan" {
  for_each = local.oidc_enabled ? toset(var.plan_policy_arns) : toset([])

  role       = aws_iam_role.plan[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "apply" {
  for_each = local.oidc_enabled ? toset(var.apply_policy_arns) : toset([])

  role       = aws_iam_role.apply[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "plan_state" {
  count = local.oidc_enabled ? 1 : 0

  name   = "terraform-state"
  role   = aws_iam_role.plan[0].id
  policy = local.state_access
}

resource "aws_iam_role_policy" "apply_state" {
  count = local.oidc_enabled ? 1 : 0

  name   = "terraform-state"
  role   = aws_iam_role.apply[0].id
  policy = local.state_access
}
