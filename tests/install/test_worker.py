# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Validate the installed `shomer-worker` Debian package."""

from __future__ import annotations

import shutil


def test_console_script_on_path() -> None:
    assert shutil.which("shomer-worker"), "shomer-worker console-script missing from PATH"


def test_module_imports(run, system_python) -> None:
    out = run(
        system_python,
        "-c",
        "import shomer_worker; print(shomer_worker.__version__)",
    )
    assert out.stdout.strip()


def test_module_version_matches_bumped_value(run, system_python, versions) -> None:
    out = run(
        system_python,
        "-c",
        "import shomer_worker; print(shomer_worker.__version__)",
    )
    installed = out.stdout.strip()
    expected = versions["worker"]
    assert installed == expected, (
        f"installed shomer_worker.__version__ = {installed!r} but VERSION says {expected!r}"
    )


def test_tick_callable_resolves(run, system_python) -> None:
    """Smoke check: the tick function imports and is callable. Avoids
    invoking `run()` directly because that would block on the polling
    loop."""
    out = run(
        system_python,
        "-c",
        "from shomer_worker.main import tick; print(callable(tick))",
    )
    assert out.stdout.strip() == "True"
