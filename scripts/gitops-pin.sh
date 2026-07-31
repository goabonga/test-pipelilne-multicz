#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>
#
# Rewrite the chart version pinned for one component in one environment.
#
#   scripts/gitops-pin.sh <env> <component> <version>
#   scripts/gitops-pin.sh staging api 1.4.0
#
# Exists as a script rather than inline sed in a workflow so the promotion
# jobs and a human fixing a pin by hand do exactly the same thing, and so
# the edit can be tested without a runner.
#
# Prints nothing and exits 0 when the pin is already at that version, so a
# promotion job can call it for every component and commit only if the tree
# actually moved.

set -euo pipefail

ENV_NAME="${1:-}"
COMPONENT="${2:-}"
VERSION="${3:-}"

die() { printf '\033[1;31m[gitops-pin]\033[0m %s\n' "$*" >&2; exit 1; }

[ -n "$ENV_NAME" ] && [ -n "$COMPONENT" ] && [ -n "$VERSION" ] \
  || die "usage: scripts/gitops-pin.sh <env> <component> <version>"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="${REPO_ROOT}/gitops/apps/${ENV_NAME}/${COMPONENT}.yaml"
[ -f "$FILE" ] || die "no pin file at gitops/apps/${ENV_NAME}/${COMPONENT}.yaml"

# Anchored on the indentation so it can only ever match the pin under
# spec.chart.spec — a looser pattern would also rewrite a `version:` that
# appeared anywhere else in the document.
CURRENT=$(sed -n 's/^      version: "\(.*\)"$/\1/p' "$FILE")
[ -n "$CURRENT" ] || die "no version pin found in ${FILE#"${REPO_ROOT}/"}"

[ "$CURRENT" = "$VERSION" ] && exit 0

sed -i "s/^      version: \"${CURRENT}\"$/      version: \"${VERSION}\"/" "$FILE"
printf '\033[1;34m[gitops-pin]\033[0m %s/%s: %s -> %s\n' "$ENV_NAME" "$COMPONENT" "$CURRENT" "$VERSION"
