#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Re-author and GPG-sign a Dependabot commit, normalising its subject to
# Conventional Commits with a type/scope that reflects what the bump touches:
#
#   - changes only under .github/workflows/ or .github/actions/ -> ci
#   - changes only under packages/web/ (npm / Node build)        -> chore(web)
#   - changes only under packages/api/                           -> fix(api)
#   - changes only under packages/job/                           -> fix(job)
#   - changes only under packages/ssr/                           -> fix(ssr)
#   - changes only under packages/cli/                           -> fix(cli)
#   - Python uv runtime bump touching one packages/<pkg>/pyproject.toml
#                                                                -> fix(<pkg>)
#   - dev-tools group / [dependency-groups].dev member           -> chore(deps)
#   - other runtime Python dep                                   -> fix(deps)
#
# Multicz then matches the changed files against each component's `paths`
# and bumps accordingly; the scope above is for humans reading the log.
#
# Run by `git rebase --exec` in dependabot-rewrite.yml.

set -euo pipefail

changed=$(git show --name-only --pretty='' HEAD)
subject=$(git log -1 --pretty=%s HEAD)
body=$(git log -1 --pretty=%b HEAD | sed '/^[Cc]o-authored-by:/d')

# Drop any leading conventional prefix Dependabot already added.
text=$(printf '%s' "$subject" | sed -E 's/^[a-z]+(\([^)]+\))?!?:[[:space:]]*//')

only_in() {
    # Exit 0 iff every changed file starts with one of the given path prefixes.
    local f p
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        for p in "$@"; do
            case "$f" in "$p"*) continue 2 ;; esac
        done
        return 1
    done <<<"$changed"
    return 0
}

any_in() {
    local f p
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        for p in "$@"; do
            case "$f" in "$p"*) return 0 ;; esac
        done
    done <<<"$changed"
    return 1
}

is_dev_dep() {
    # Exit 0 if $1 is declared in [dependency-groups].dev of root pyproject.toml.
    python3 - "$1" <<'PY' 2>/dev/null || return 1
import sys, tomllib

pkg = sys.argv[1].strip().lower().replace("_", "-")
data = tomllib.load(open("pyproject.toml", "rb"))
dev = data.get("dependency-groups", {}).get("dev", [])


def name(spec: str) -> str:
    for sep in ("[", ">", "<", "=", "~", "!", ";", " "):
        spec = spec.split(sep)[0]
    return spec.strip().lower().replace("_", "-")


names = {name(d) for d in dev if isinstance(d, str)}
sys.exit(0 if pkg in names else 1)
PY
}

prefix=""

if only_in ".github/workflows/" ".github/actions/"; then
    prefix="ci"
elif only_in "packages/web/"; then
    prefix="chore(web)"
else
    # Single-package scope detection: only one packages/<pkg>/ touched
    # (uv.lock at root is allowed alongside it for Python bumps).
    pkg_scope=""
    multi=0
    for p in api job ssr cli; do
        if any_in "packages/$p/"; then
            if [ -z "$pkg_scope" ]; then
                pkg_scope="$p"
            else
                multi=1
            fi
        fi
    done

    if [ "$multi" = "0" ] && [ -n "$pkg_scope" ] && only_in "packages/$pkg_scope/" "uv.lock"; then
        # Docker base bump (touches only packages/<pkg>/Dockerfile) ships in prod.
        if any_in "packages/$pkg_scope/Dockerfile"; then
            prefix="fix($pkg_scope)"
        elif printf '%s' "$text" | grep -qiE 'dev-tools group'; then
            prefix="chore(deps)"
        else
            dep=$(printf '%s' "$text" | sed -nE 's/^[Bb]ump ([A-Za-z0-9._-]+) from .*/\1/p')
            if [ -n "$dep" ] && is_dev_dep "$dep"; then
                prefix="chore(deps)"
            else
                prefix="fix($pkg_scope)"
            fi
        fi
    elif printf '%s' "$text" | grep -qiE 'dev-tools group'; then
        prefix="chore(deps)"
    else
        # Fall back to the flat-repo classifier.
        dep=$(printf '%s' "$text" | sed -nE 's/^[Bb]ump ([A-Za-z0-9._-]+) from .*/\1/p')
        if [ -n "$dep" ] && is_dev_dep "$dep"; then
            prefix="chore(deps)"
        elif [ -n "$dep" ]; then
            prefix="fix(deps)"
        else
            prefix="chore(deps)"
        fi
    fi
fi

# For runtime bumps, sync packages/<pkg>/pyproject.toml's lower-bound
# specifier to the freshly-installed version and re-lock so the
# `requires-dist` mirror in uv.lock matches pyproject. This closes the
# Dependabot uv FileUpdater gap that touches the lockfile mirror but
# leaves pyproject.toml untouched on `>=X` specifiers, producing a
# silent drift that uv lock undoes on the next run.
#
# We also use the dep -> package map to refine `fix(deps)` into
# `fix(<pkg>)` when exactly one workspace member declares the dep,
# so multicz's `detect` step sees `packages/<pkg>/pyproject.toml`
# change and runs the right component's tests + release.
if [[ "$prefix" == fix* ]]; then
    bumped_dep=$(printf '%s' "$text" | sed -nE 's/^[Bb]ump ([A-Za-z0-9._-]+) from .* to ([0-9][0-9A-Za-z.+-]*).*/\1/p')
    new_version=$(printf '%s' "$text" | sed -nE 's/^[Bb]ump ([A-Za-z0-9._-]+) from .* to ([0-9][0-9A-Za-z.+-]*).*/\2/p')

    if [ -n "$bumped_dep" ] && [ -n "$new_version" ]; then
        affected=()
        for pyproject in packages/*/pyproject.toml; do
            if python3 - "$pyproject" "$bumped_dep" >/dev/null 2>&1 <<'PY'
import sys, tomllib

path, want = sys.argv[1], sys.argv[2].strip().lower().replace("_", "-")
data = tomllib.load(open(path, "rb"))
deps = data.get("project", {}).get("dependencies", [])


def normalize(spec: str) -> str:
    for sep in ("[", ">", "<", "=", "~", "!", ";", " "):
        spec = spec.split(sep)[0]
    return spec.strip().lower().replace("_", "-")


sys.exit(0 if want in {normalize(d) for d in deps if isinstance(d, str)} else 1)
PY
            then
                affected+=("$(basename "$(dirname "$pyproject")")")
            fi
        done

        if [ ${#affected[@]} -gt 0 ]; then
            for pkg in "${affected[@]}"; do
                python3 - "packages/$pkg/pyproject.toml" "$bumped_dep" "$new_version" <<'PY'
import re, sys

path, dep, new_version = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
# Match a single-quoted dependency entry, capturing optional [extras] and
# any existing constraint (`>=`, `==`, `~=`, …). We rewrite the constraint
# to a pure `>=<new_version>` lower bound, preserving extras and indent.
pattern = re.compile(
    r'(?P<indent>\s*)"(?P<name>' + re.escape(dep) + r')'
    r'(?P<extras>\[[^\]]+\])?'
    r'(?P<spec>[><=~!,][^"]*)?"',
    re.IGNORECASE,
)


def repl(m: re.Match) -> str:
    return f'{m["indent"]}"{m["name"]}{m["extras"] or ""}>={new_version}"'


new_text = pattern.sub(repl, text, count=1)
if new_text != text:
    open(path, "w").write(new_text)
PY
            done

            # Re-resolve so uv.lock's [package.metadata] mirror lines up
            # with the new pyproject specifiers, and we land a single
            # consistent commit instead of leaking a drift forwards.
            uv lock --quiet

            # Single-package match -> tighten the scope so multicz attributes
            # the bump to the right component (fix(deps) is the fallback
            # when several packages declare the same runtime dep).
            if [ ${#affected[@]} -eq 1 ]; then
                prefix="fix(${affected[0]})"
            fi

            git add packages/*/pyproject.toml uv.lock
        fi
    fi
fi

if [ -n "$body" ]; then
    new_msg=$(printf '%s: %s\n\n%s' "$prefix" "$text" "$body")
else
    new_msg=$(printf '%s: %s' "$prefix" "$text")
fi

git commit --amend --reset-author -m "$new_msg" --quiet
