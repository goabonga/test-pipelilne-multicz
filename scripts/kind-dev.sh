#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>
#
# Bring the full stack up on a local kind cluster: postgres, the alembic
# migration Job, then api / job / ssr from locally built images.
#
# This mirrors what CI does in `.github/actions/db-stack` and
# `.github/actions/e2e-stack` — same charts, same release names, same
# `--set` overrides — with two differences: images are built from the
# working tree instead of pulled from an artifact or ghcr, and
# replicaCount drops to 1. The postgres manifest is the very same file
# CI applies, so the dev database can't drift from the CI one.
#
# Usage:  scripts/kind-dev.sh <up|down|status|logs|forward> [args]
#         (or the `make kind-*` targets)

set -euo pipefail

CLUSTER="${KIND_CLUSTER:-shomer-dev}"
TAG="dev"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POSTGRES_MANIFEST="${REPO_ROOT}/.github/actions/db-stack/postgres.yaml"

# Component -> "<docker build context>:<Dockerfile path>". migrations
# builds from packages/bdd because its Dockerfile reaches up into the
# sibling database package.
APPS=(api job ssr)

log() { printf '\033[1;34m[kind-dev]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[kind-dev]\033[0m %s\n' "$*" >&2; exit 1; }

require_tools() {
  local missing=()
  for t in docker kind kubectl helm; do
    command -v "$t" >/dev/null 2>&1 || missing+=("$t")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    die "missing required tool(s): ${missing[*]}
  kind    https://kind.sigs.k8s.io/docs/user/quick-start/#installation
  kubectl https://kubernetes.io/docs/tasks/tools/
  helm    https://helm.sh/docs/intro/install/"
  fi
  docker info >/dev/null 2>&1 || die "docker daemon is not reachable"
}

# kubectl/helm talk to the cluster through this context explicitly rather
# than relying on whatever the user's current-context happens to be — a
# local `make kind-up` must never deploy into someone's real cluster.
kctx() { kubectl --context "kind-${CLUSTER}" "$@"; }
hctx() { helm --kube-context "kind-${CLUSTER}" "$@"; }

# --provenance=false --sbom=false: buildx otherwise emits a manifest list
# carrying attestation manifests, and `kind load docker-image` fails on it
# with "ctr images import ... exit status 1". CI dodges this because
# build-push-action's `load: true` is itself incompatible with those
# attestations (it attaches them post-push via cosign instead), so the
# images it hands to kind are already plain single-platform ones.
BUILD_FLAGS=(--provenance=false --sbom=false)

build_images() {
  log "building images from the working tree (tag :${TAG})"
  for c in "${APPS[@]}"; do
    log "  -> ${c}:${TAG}"
    docker build "${BUILD_FLAGS[@]}" -t "${c}:${TAG}" "${REPO_ROOT}/packages/${c}"
  done
  log "  -> migrations:${TAG}"
  docker build "${BUILD_FLAGS[@]}" -t "migrations:${TAG}" \
    -f "${REPO_ROOT}/packages/bdd/migrations/Dockerfile" \
    "${REPO_ROOT}/packages/bdd"
}

# Only our own images are side-loaded. CI additionally preloads
# postgres:17, but that only works there because its docker keeps the
# classic image store, where a pull flattens to one platform. With the
# containerd store (docker >= 28 default) the pulled image stays a
# manifest list and `kind load` dies on it — so the node pulls postgres
# from the registry itself, which costs one pull on first `up`.
load_images() {
  log "loading images into kind"
  for c in "${APPS[@]}" migrations; do
    kind load docker-image "${c}:${TAG}" --name "${CLUSTER}"
  done
}

cmd_up() {
  require_tools

  if kind get clusters 2>/dev/null | grep -qx "${CLUSTER}"; then
    log "cluster '${CLUSTER}' already exists — reusing it"
  else
    log "creating kind cluster '${CLUSTER}'"
    kind create cluster --name "${CLUSTER}" --wait 60s
  fi

  build_images
  load_images

  log "deploying postgres"
  kctx apply -f "${POSTGRES_MANIFEST}"
  kctx rollout status deploy/postgres --timeout=120s

  # Uninstall rather than upgrade: the chart names its Job after the
  # appVersion, and a Job's spec is immutable, so re-running `up` at an
  # unchanged version would make helm try to patch it and fail.
  log "running migrations (alembic upgrade head)"
  hctx uninstall migrations --ignore-not-found --wait >/dev/null 2>&1 || true
  hctx install migrations "${REPO_ROOT}/packages/bdd/migrations/chart" \
    --set image.repository=migrations \
    --set image.tag="${TAG}" \
    --set image.pullPolicy=IfNotPresent \
    --set database.existingSecret=shomer-db \
    --wait --timeout 2m

  for c in "${APPS[@]}"; do
    log "installing ${c}"
    hctx upgrade --install "${c}" "${REPO_ROOT}/packages/${c}/chart" \
      --set image.repository="${c}" \
      --set image.tag="${TAG}" \
      --set image.pullPolicy=IfNotPresent \
      --set replicaCount=1 \
      --wait --timeout 2m
  done

  log "stack is up"
  kctx get pods
  cat <<EOF

  Expose the services with:  make kind-forward
    api -> http://localhost:8000/healthz
    ssr -> http://localhost:8080/healthz

  Tear down with:            make kind-down
EOF
}

cmd_down() {
  require_tools
  if kind get clusters 2>/dev/null | grep -qx "${CLUSTER}"; then
    log "deleting kind cluster '${CLUSTER}'"
    kind delete cluster --name "${CLUSTER}"
  else
    log "no cluster named '${CLUSTER}' — nothing to do"
  fi
}

cmd_status() {
  require_tools
  kctx get all
}

cmd_logs() {
  require_tools
  local comp="${1:-}"
  [ -n "${comp}" ] || die "usage: scripts/kind-dev.sh logs <api|job|ssr|migrations|postgres>"
  if [ "${comp}" = "postgres" ]; then
    kctx logs -l app=postgres --tail=200 -f
  else
    kctx logs -l "app.kubernetes.io/name=shomer-${comp}" --tail=200 -f
  fi
}

# Both forwards run in the foreground so Ctrl-C reclaims the ports; the
# trap kills the background api forward too, otherwise it survives and
# the next `make kind-forward` fails on an address already in use.
cmd_forward() {
  require_tools
  log "forwarding api -> localhost:8000, ssr -> localhost:8080 (Ctrl-C to stop)"
  kctx port-forward svc/api 8000:8000 &
  local api_pf=$!
  trap 'kill "${api_pf}" 2>/dev/null || true' EXIT INT TERM
  kctx port-forward svc/ssr 8080:8080
}

case "${1:-}" in
  up)      shift; cmd_up "$@" ;;
  down)    shift; cmd_down "$@" ;;
  status)  shift; cmd_status "$@" ;;
  logs)    shift; cmd_logs "$@" ;;
  forward) shift; cmd_forward "$@" ;;
  *)       die "usage: scripts/kind-dev.sh <up|down|status|logs|forward>" ;;
esac
