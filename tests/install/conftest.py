# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Shared fixtures for the install-validation suite (`tests/install/`).

These tests run on a CI runner that has just `apt-get install`-ed a
freshly-built .deb. They MUST probe the *system* Python
(`/usr/bin/python3`) rather than the test runner's venv — `apt`
installs to `/usr/lib/python3/dist-packages/`, which only the system
interpreter sees.
"""

from __future__ import annotations

import subprocess
from collections.abc import Callable
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
VERSION_FILE = REPO_ROOT / "VERSION"
SYSTEM_PYTHON = "/usr/bin/python3"


@pytest.fixture(scope="session")
def versions() -> dict[str, str]:
    """Map component name → expected version, parsed from the workspace
    `VERSION` file (lines like ``api=1.2.3``).

    In CI this file is rewritten by ``multicz bump --no-post-bump
    --no-changelog`` (the bump-preview composite action) BEFORE the
    .deb is built, so its contents match exactly what each installed
    package must report.
    """
    out: dict[str, str] = {}
    for raw in VERSION_FILE.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        name, _, value = line.partition("=")
        out[name.strip()] = value.strip()
    return out


@pytest.fixture
def system_python() -> str:
    """Absolute path to the system interpreter — bypasses any venv the
    test runner itself is in (uv-managed, virtualenv, pipx). The .deb
    only registers its package under the system `dist-packages`."""
    return SYSTEM_PYTHON


@pytest.fixture
def run() -> Callable[..., subprocess.CompletedProcess[str]]:
    """Subprocess wrapper: captures text output, raises on non-zero
    exit. Use for any installed-binary or system-Python invocation."""

    def _run(*args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(args, check=True, text=True, capture_output=True)

    return _run
