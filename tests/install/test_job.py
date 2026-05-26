# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Validate the installed `shomer-job` Debian package."""

from __future__ import annotations

import shutil


def test_console_script_on_path() -> None:
    assert shutil.which("shomer-job"), "shomer-job console-script missing from PATH"


def test_module_imports(run, system_python) -> None:
    out = run(
        system_python,
        "-c",
        "import shomer_job; print(shomer_job.__version__)",
    )
    assert out.stdout.strip()


def test_module_version_matches_bumped_value(run, system_python, versions) -> None:
    out = run(
        system_python,
        "-c",
        "import shomer_job; print(shomer_job.__version__)",
    )
    installed = out.stdout.strip()
    expected = versions["job"]
    assert installed == expected, (
        f"installed shomer_job.__version__ = {installed!r} but VERSION says {expected!r}"
    )


def test_tick_callable_resolves(run, system_python) -> None:
    """Smoke check: the tick function imports and is callable. Avoids
    invoking `run()` directly because that would block on the polling
    loop."""
    out = run(
        system_python,
        "-c",
        "from shomer_job.main import tick; print(callable(tick))",
    )
    assert out.stdout.strip() == "True"


def test_appstream_metainfo_installed() -> None:
    from pathlib import Path

    metainfo = Path("/usr/share/metainfo/shomer-job.metainfo.xml")
    assert metainfo.is_file(), f"missing {metainfo}"
    body = metainfo.read_text()
    assert "<id>io.github.goabonga.shomer-job</id>" in body
    assert "<icon type=\"stock\">shomer-job</icon>" in body


def test_hicolor_icon_installed() -> None:
    from pathlib import Path

    icon = Path("/usr/share/icons/hicolor/scalable/apps/shomer-job.svg")
    assert icon.is_file(), f"missing {icon}"
    assert icon.read_text().lstrip().startswith("<?xml")
