.PHONY: help install hooks lint format test header headers-check docs docs-dev \
        release-status release-plan release-validate release-config release-graph \
        release-dry-run release kind-up kind-down kind-status kind-logs \
        kind-forward infra-fmt infra-fmt-check infra-test infra-plan \
        infra-new-module infra-docs infra-docs-check infra-checkov \
        infra-fmt-check-root infra-lint \
        infra-clean clean

VENV     := .venv
UV       := uv
RUFF     := $(VENV)/bin/ruff
PYTEST   := $(VENV)/bin/pytest
ZENSICAL := $(VENV)/bin/zensical
PYTHON   := $(VENV)/bin/python
# Run multicz via uvx — pulls the latest from PyPI on first call, cached
# afterwards. Avoids adding multicz to the workspace dev group.
MULTICZ  := uvx multicz

# Default target prints the help block so `make` alone is always safe.
help:
	@echo "Shomer - Development Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make install         Sync the workspace venv (all packages + dev/doc/favicon groups)"
	@echo "  make hooks           Install the pre-commit / pre-push git hooks"
	@echo ""
	@echo "Quality:"
	@echo "  make lint            Run ruff check across packages and scripts"
	@echo "  make format          Format code with ruff"
	@echo "  make test            Run pytest across all workspace members"
	@echo "  make header          Apply the SPDX license header to every .py file (in-place)"
	@echo "  make headers-check   Verify every .py file already carries the SPDX header (CI-safe)"
	@echo ""
	@echo "Docs:"
	@echo "  make docs            Build the static site into ./site"
	@echo "  make docs-dev        Serve docs with live reload (http://127.0.0.1:8800)"
	@echo ""
	@echo "Release (multicz):"
	@echo "  make release-status   Show pending bumps (one-line per component)"
	@echo "  make release-plan     Full bump plan with reasons"
	@echo "  make release-validate Sanity-check multicz.toml against the repo"
	@echo "  make release-config   Print the effective multicz config"
	@echo "  make release-graph    Render the cascade DAG (api/job -> charts)"
	@echo "  make release-dry-run  Compute the bump but write nothing"
	@echo "  make release          Apply versions, commit and tag (no push)"
	@echo ""
	@echo "Local cluster (kind):"
	@echo "  make kind-up         Build the images and deploy the full stack on kind"
	@echo "  make kind-forward    Port-forward api (:8000) and ssr (:8080) to localhost"
	@echo "  make kind-status     Show what is running in the cluster"
	@echo "  make kind-logs C=api Tail one component (api|job|ssr|migrations|postgres)"
	@echo "  make kind-down       Delete the cluster"
	@echo ""
	@echo "Infrastructure (terragrunt):"
	@echo "  make infra-fmt         terraform fmt + terragrunt hcl format, in place"
	@echo "  make infra-fmt-check   same, non-mutating (what CI runs)"
	@echo "  make infra-lint        terragrunt hcl validate + inputs/variables cross-check"
	@echo "  make infra-test        terraform test on the modules (M=<name> for one)"
	@echo "  make infra-checkov     checkov on the modules (M=<name> for one)"
	@echo "  make infra-plan        terragrunt plan for one env (ENV=staging by default)"
	@echo "  make infra-docs        regenerate every module README with terraform-docs"
	@echo "  make infra-docs-check  verify those READMEs are up to date (what CI runs)"
	@echo "  make infra-new-module NAME=<name>  scaffold + register a Terraform module"
	@echo "  make infra-clean       drop .terragrunt-cache / lockfiles / generated *.tf"
	@echo ""
	@echo "Misc:"
	@echo "  make clean           Remove caches, build artefacts and ./site"

# uv sync installs every workspace member plus the dev / doc / favicon
# dependency groups, all resolved against uv.lock for reproducibility.
install:
	$(UV) sync --all-packages --group dev --group doc --group favicon

# Register the git hooks defined in .pre-commit-config.yaml. Needs the
# dev group (pre-commit) installed — run `make install` first.
hooks:
	$(UV) run pre-commit install --install-hooks -t pre-commit -t pre-push

lint:
	$(UV) run ruff check packages scripts

format:
	$(UV) run ruff format packages scripts

test:
	$(UV) run pytest

# Apply / check the SPDX license header on every .py file under the
# workspace. Both targets walk packages/ and scripts/ — extend the
# --path list if you add new top-level source roots.
header:
	$(UV) run python scripts/add_license_header.py --path packages
	$(UV) run python scripts/add_license_header.py --path scripts

headers-check:
	$(UV) run python scripts/add_license_header.py --path packages --check
	$(UV) run python scripts/add_license_header.py --path scripts --check

docs:
	$(UV) run zensical build

docs-dev:
	$(UV) run zensical serve --dev-addr 127.0.0.1:8800

# multicz wrappers. The binary is invoked through `uvx multicz`, so the
# first call downloads it from PyPI (~1s) and subsequent calls hit the
# uv cache. To pin a version: MULTICZ="uvx multicz==1.0.0" make ...
release-status:
	$(MULTICZ) status

release-plan:
	$(MULTICZ) plan

release-validate:
	$(MULTICZ) validate --strict

release-config:
	$(MULTICZ) config

release-graph:
	$(MULTICZ) graph

release-dry-run:
	$(MULTICZ) bump --dry-run

# `make release` applies the bump locally — commits and tags but does
# NOT push. Push manually (`git push --follow-tags`) or via CI once the
# release commit looks right.
release:
	$(MULTICZ) bump --commit --tag

# Local kind cluster running the same charts CI deploys, with images
# built from the working tree instead of pulled from ghcr. Needs docker,
# kind, kubectl and helm on PATH — `kind-up` checks and says which are
# missing. Override the cluster name with KIND_CLUSTER=... if `shomer-dev`
# collides with something you already have.
KIND_DEV := scripts/kind-dev.sh

kind-up:
	$(KIND_DEV) up

kind-down:
	$(KIND_DEV) down

kind-status:
	$(KIND_DEV) status

# C selects the component: `make kind-logs C=api`.
kind-logs:
	$(KIND_DEV) logs $(C)

kind-forward:
	$(KIND_DEV) forward

# ─────────────────────────── infrastructure ───────────────────────────
# Terragrunt lives under infrastructure/; the shell helpers that wrap the
# CLI for interactive use are in scripts/terragrunt.sh (source it, don't
# execute it). These targets are the non-interactive equivalents CI runs.
INFRA_DIR := infrastructure
# `?=` so `make infra-plan ENV=production` wins, and an ENV already
# exported in the shell (e.g. after `switch_env`) is honoured too.
ENV ?= staging

# M=<name> narrows every infra target to one module. Without it they sweep
# the whole tree, which is the useful local default; CI passes M so each
# component gets its own job, the same way api-* / job-* / chart-* do.
infra-fmt:
	@set -eu; \
	if [ -n "$(M)" ]; then \
		terraform fmt -recursive $(INFRA_DIR)/modules/$(M); \
	else \
		terraform fmt -recursive $(INFRA_DIR)/modules; \
		terragrunt --working-dir $(INFRA_DIR) hcl format; \
	fi

infra-fmt-check:
	@set -eu; \
	if [ -n "$(M)" ]; then \
		terraform fmt -check -recursive $(INFRA_DIR)/modules/$(M); \
	else \
		terraform fmt -check -recursive $(INFRA_DIR)/modules; \
		terragrunt --working-dir $(INFRA_DIR) hcl format --check; \
	fi

# The `infra` component's own share of the formatting: the terragrunt
# wiring plus the scaffold. Each module checks itself through
# `infra-fmt-check M=<name>`.
infra-fmt-check-root:
	terragrunt --working-dir $(INFRA_DIR) hcl format --check
	terraform fmt -check -recursive $(INFRA_DIR)/modules/_template

# Lint the terragrunt wiring itself — formatting says nothing about whether
# it is CORRECT.
#
# Two passes, deliberately:
#
#   1. `hcl validate` over the whole tree, with no ENV. Parses every file
#      and resolves every reference; catches a typo in root.hcl or a broken
#      include without touching a provider.
#
#   2. `hcl validate --inputs --strict` per environment. This is the one
#      that earns its place: it cross-checks each unit's `inputs` against
#      the module's declared variables. A missing required input exits 1 on
#      its own; --strict promotes an input the module does not declare from
#      a warning to an error too. Both are bugs that would otherwise only
#      surface at plan time, against a real provider.
#
# Neither needs credentials, a backend or a provider — only the module
# source, which is a local path.
infra-lint:
	terragrunt --working-dir $(INFRA_DIR) hcl validate
	@set -eu; \
	for dir in $(INFRA_DIR)/configs/*/; do \
		env_name=$$(basename "$$dir"); \
		echo "==> hcl validate --inputs --strict (ENV=$$env_name)"; \
		ENV=$$env_name terragrunt --working-dir $(INFRA_DIR)/services \
			hcl validate --inputs --strict; \
	done

# M selects one module: `make infra-test M=example`. Empty means all of
# them, which is the useful default locally; CI passes M so it only
# exercises the modules multicz reports as changed.
# _template is excluded from the default sweep: it is a scaffold, not a
# module — nothing consumes it and it declares no resources, so testing and
# scanning it is noise. `M=_template` still targets it explicitly.
MODULES = $(if $(M),$(INFRA_DIR)/modules/$(M)/,\
            $(filter-out %/_template/,$(wildcard $(INFRA_DIR)/modules/*/)))

# `mock_provider` intercepts every provider call, so this needs no
# credentials and no network — which is why the CI job has no cloud login.
infra-test:
	@set -eu; \
	for dir in $(MODULES); do \
		if [ -d "$${dir}tests" ]; then \
			echo "==> terraform test $${dir}"; \
			(cd "$${dir}" && terraform init -backend=false -input=false >/dev/null && terraform test); \
		fi; \
	done

# Same scan CI runs through bridgecrewio/checkov-action. Falls back to uvx
# so it works without installing checkov, like MULTICZ above.
CHECKOV := $(shell command -v checkov 2>/dev/null || echo uvx checkov)

infra-checkov:
	@set -eu; \
	for dir in $(MODULES); do \
		echo "==> checkov $${dir}"; \
		$(CHECKOV) -d "$${dir}" --framework terraform --quiet --compact; \
	done

# ENV picks the configs/<env>/config.yaml the units read: make infra-plan ENV=production
infra-plan:
	ENV=$(ENV) terragrunt --non-interactive --working-dir $(INFRA_DIR)/services \
		run --all -- plan -input=false

# Each module carries its own .terraform-docs.yml and records its version
# in README.md (there is no VERSION file) — `mode: inject` only rewrites
# what sits between the BEGIN_TF_DOCS / END_TF_DOCS markers, so the
# **Version:** line and any hand-written prose survive. multicz runs the
# same command as a post_bump hook, so a released module always ships docs
# matching the code that was tagged.
infra-docs:
	@set -eu; \
	for dir in $(MODULES); do \
		if [ -f "$${dir}.terraform-docs.yml" ]; then \
			terraform-docs -c "$${dir}.terraform-docs.yml" "$${dir}"; \
		fi; \
	done

infra-docs-check:
	@set -eu; \
	for dir in $(MODULES); do \
		if [ -f "$${dir}.terraform-docs.yml" ]; then \
			echo "==> terraform-docs --output-check $${dir}"; \
			terraform-docs -c "$${dir}.terraform-docs.yml" --output-check "$${dir}"; \
		fi; \
	done

infra-new-module:
	@test -n "$(NAME)" || { echo "usage: make infra-new-module NAME=<name>"; exit 1; }
	scripts/new-terraform-module.sh $(NAME)

infra-clean:
	find $(INFRA_DIR) -type d -name ".terragrunt-cache" -prune -exec rm -rf {} + 2>/dev/null || true
	find $(INFRA_DIR) -type f -name ".terraform.lock.hcl" -delete
	find $(INFRA_DIR) -type f -name "generated_*.tf" -delete

clean:
	rm -rf site/ build/ dist/
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
	find . -type d -name .pytest_cache -prune -exec rm -rf {} +
	find . -type d -name .ruff_cache -prune -exec rm -rf {} +
