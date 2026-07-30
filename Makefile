.PHONY: help install hooks lint format test header headers-check docs docs-dev \
        release-status release-plan release-validate release-config release-graph \
        release-dry-run release kind-up kind-down kind-status kind-logs \
        kind-forward clean

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

clean:
	rm -rf site/ build/ dist/
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
	find . -type d -name .pytest_cache -prune -exec rm -rf {} +
	find . -type d -name .ruff_cache -prune -exec rm -rf {} +
