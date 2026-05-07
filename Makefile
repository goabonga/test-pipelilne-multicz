.PHONY: help install lint format test header headers-check docs docs-dev clean

VENV     := .venv
UV       := uv
RUFF     := $(VENV)/bin/ruff
PYTEST   := $(VENV)/bin/pytest
ZENSICAL := $(VENV)/bin/zensical
PYTHON   := $(VENV)/bin/python

# Default target prints the help block so `make` alone is always safe.
help:
	@echo "Shomer - Development Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make install         Sync the workspace venv (all packages + dev/doc/favicon groups)"
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
	@echo "Misc:"
	@echo "  make clean           Remove caches, build artefacts and ./site"

# uv sync installs every workspace member plus the dev / doc / favicon
# dependency groups, all resolved against uv.lock for reproducibility.
install:
	$(UV) sync --all-packages --group dev --group doc --group favicon

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

clean:
	rm -rf site/ build/ dist/
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
	find . -type d -name .pytest_cache -prune -exec rm -rf {} +
	find . -type d -name .ruff_cache -prune -exec rm -rf {} +
