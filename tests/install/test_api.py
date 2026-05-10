# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Validate the installed `shomer-api` Debian package.

Runs AFTER the matching `api-deb` job built and uploaded the .deb
artifact and the `api-deb-validate` job downloaded + apt-installed
it. Probes the system-installed package only — never the workspace
editable install.
"""

from __future__ import annotations

import shutil


def test_console_script_on_path() -> None:
    assert shutil.which("shomer-api"), "shomer-api console-script missing from PATH"


def test_module_imports(run, system_python) -> None:
    out = run(
        system_python,
        "-c",
        "import shomer_api; print(shomer_api.__version__)",
    )
    assert out.stdout.strip(), "shomer_api.__version__ resolved to an empty string"


def test_module_version_matches_bumped_value(run, system_python, versions) -> None:
    out = run(
        system_python,
        "-c",
        "import shomer_api; print(shomer_api.__version__)",
    )
    installed = out.stdout.strip()
    expected = versions["api"]
    assert installed == expected, (
        f"installed shomer_api.__version__ = {installed!r} but VERSION says {expected!r}"
    )


def test_fastapi_app_object_loads(run, system_python) -> None:
    out = run(
        system_python,
        "-c",
        "from shomer_api.app import app; print(app.title, app.version)",
    )
    assert "Shomer" in out.stdout
