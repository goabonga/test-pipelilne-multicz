#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>
#
# Create the CI identity for one cloud and set the GitHub variables that
# point at it.
#
#   scripts/setup-oidc.sh gcp
#   scripts/setup-oidc.sh aws --dry-run
#
# WHAT IT CREATES
#
#   GCP   a workload identity pool + provider, and two service accounts
#         (-plan read-only, -apply)
#   AWS   an OIDC provider for GitHub, and two roles (-plan read-only,
#         -apply)
#
# and then sets, on the matching GitHub environments:
#
#   GCP   GCP_WORKLOAD_IDENTITY_PROVIDER, GCP_SERVICE_ACCOUNT
#   AWS   AWS_ROLE_ARN, AWS_REGION
#
# NONE OF THOSE ARE SECRETS. A role ARN, a provider path and a service
# account email are identifiers; they are useless without a token GitHub
# will only mint for this repository. That is why they are variables and
# why this script prints them rather than hiding them.
#
# Run it with the same elevated credentials the bootstrap needed — it
# creates IAM. The identities it makes are what CI uses afterwards, and
# they are far weaker.

set -euo pipefail

CLOUD=${1:-}
DRY_RUN=false
[ "${2:-}" = "--dry-run" ] && DRY_RUN=true

REPO_ROOT=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
cd "$REPO_ROOT"

die() { echo "error: $*" >&2; exit 1; }

case "$CLOUD" in
  aws|gcp) ;;
  *) die "usage: scripts/setup-oidc.sh aws|gcp [--dry-run]" ;;
esac

command -v terraform >/dev/null || die "terraform is not installed"
command -v gh >/dev/null        || die "gh is not installed"
command -v jq >/dev/null        || die "jq is not installed"

REPO=${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}
[ -n "$REPO" ] || die "could not determine the repository; set REPO=owner/repo"

# WHICH ENVIRONMENT THIS CLOUD SERVES is not a second list to maintain —
# it is `provider:` in the environment configs, the same key that picks the
# module, the terragrunt provider block and the backend. Deriving it here
# means this script cannot disagree with the pipeline.
mapfile -t ENVS < <(
  grep -l "^provider: ${CLOUD}\$" infrastructure/configs/*/config.yaml 2>/dev/null \
    | xargs -r -n1 dirname | xargs -r -n1 basename
)

case ${#ENVS[@]} in
  0) die "no environment under infrastructure/configs declares 'provider: ${CLOUD}' — nothing to wire" ;;
  1) ENV_NAME=${ENVS[0]} ;;
  *) die "more than one environment runs on ${CLOUD} (${ENVS[*]}); this script wires one identity pair per cloud" ;;
esac

DIR="infrastructure/bootstrap/${CLOUD}"
[ -d "$DIR" ] || die "$DIR does not exist"

echo "==> ${CLOUD}: environment ${ENV_NAME}, repository ${REPO}"

# AWS credentials are a special case worth handling rather than
# documenting. Terraform's Go SDK does not understand the `aws login`
# session the CLI keeps in ~/.aws/login — it fails with "No valid
# credential sources found" while `aws sts get-caller-identity` succeeds,
# which reads as a broken script rather than a missing bridge.
if [ "$CLOUD" = "aws" ] && [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
  if creds=$(aws configure export-credentials --format env 2>/dev/null); then
    eval "$creds"
    echo "    bridged the aws CLI session into the environment"
  fi
fi

cd "$DIR"

# The bucket already exists, so its settings are in state rather than in
# somebody's shell history. Re-deriving them here means this cannot be run
# with a different bucket name than the one it is about to grant access to.
terraform init -input=false >/dev/null

BUCKET=$(terraform output -raw bucket 2>/dev/null) \
  || die "no state for ${DIR} — run 'make infra-bootstrap CLOUD=${CLOUD} ...' first"

ARGS=(-var "bucket=${BUCKET}" -var "github_repository=${REPO}" -var "plan_environment=${ENV_NAME}-plan")

if [ "$CLOUD" = "aws" ]; then
  REGION=$(terraform output -raw region)
  ARGS+=(-var "region=${REGION}")
  # An invalid AWS_REGION in ~/.aws/config makes every call hang on an
  # endpoint that does not resolve, so the bucket's own region wins here.
  export AWS_REGION="$REGION"
  echo "    bucket ${BUCKET} in ${REGION}"
else
  PROJECT=$(grep -oP '^\s*project:\s*\K\S+' "../../configs/${ENV_NAME}/config.yaml" | head -1)
  LOCATION=$(terraform output -raw location)
  [ -n "$PROJECT" ] || die "no 'project:' in configs/${ENV_NAME}/config.yaml"
  ARGS+=(-var "project=${PROJECT}" -var "location=${LOCATION}")
  echo "    bucket ${BUCKET} in ${LOCATION}, project ${PROJECT}"
fi

if [ "$DRY_RUN" = true ]; then
  echo "==> plan only"
  terraform plan -input=false "${ARGS[@]}"
  exit 0
fi

echo "==> applying"
terraform apply -input=false -auto-approve "${ARGS[@]}"

# ── hand the values to GitHub ───────────────────────────────────────────

VARS=$(terraform output -json github_variables)
[ "$VARS" != "{}" ] || die "the apply produced no variables — github_repository was empty?"

cd "$REPO_ROOT"

echo
echo "==> setting GitHub environment variables"
failed=0
while IFS=$'\t' read -r env key value; do
  [ -n "$env" ] || continue
  if gh variable set "$key" --env "$env" --repo "$REPO" --body "$value" 2>/dev/null; then
    printf '    %-16s %-32s %s\n' "$env" "$key" "$value"
  else
    printf '    %-16s %-32s FAILED — does the environment exist?\n' "$env" "$key"
    failed=1
  fi
done < <(jq -r 'to_entries[] | .key as $e | .value | to_entries[] | "\($e)\t\(.key)\t\(.value)"' <<<"$VARS")

echo
if [ "$failed" -ne 0 ]; then
  echo "Some variables could not be set. Create the environment first:"
  echo "  gh api -X PUT repos/${REPO}/environments/<name>"
  exit 1
fi

echo "${CLOUD} is wired. The next infra-plan for ${ENV_NAME} authenticates without a stored key."
