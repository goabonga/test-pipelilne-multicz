# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Validate the installed `shomer-cli` Debian package.

Note: the console-script is `shomer` (not `shomer-cli`) — defined in
`packages/cli/pyproject.toml#project.scripts`."""

from __future__ import annotations

import shutil


def test_console_script_on_path() -> None:
    assert shutil.which("shomer"), "shomer console-script missing from PATH"


def test_help_runs_without_error(run) -> None:
    """typer responds to ``--help`` with exit 0 — covers the whole
    Typer app wiring (subcommand registration, callbacks, ...)."""
    out = run("shomer", "--help")
    assert "Usage" in out.stdout or "shomer" in out.stdout.lower()


def test_version_subcommand_matches_bumped(run, versions) -> None:
    out = run("shomer", "version")
    assert out.stdout.strip() == versions["cli"], (
        f"`shomer version` printed {out.stdout.strip()!r} but VERSION says {versions['cli']!r}"
    )


def test_module_imports_and_version_matches(run, system_python, versions) -> None:
    out = run(
        system_python,
        "-c",
        "import shomer_cli; print(shomer_cli.__version__)",
    )
    installed = out.stdout.strip()
    expected = versions["cli"]
    assert installed == expected, (
        f"installed shomer_cli.__version__ = {installed!r} but VERSION says {expected!r}"
    )


def test_appstream_metainfo_installed() -> None:
    """AppCenter / GNOME Software pick up the icon + summary from
    `/usr/share/metainfo/shomer-cli.metainfo.xml`. Without it the
    package shows the generic .deb icon."""
    from pathlib import Path

    metainfo = Path("/usr/share/metainfo/shomer-cli.metainfo.xml")
    assert metainfo.is_file(), f"missing {metainfo}"
    body = metainfo.read_text()
    assert "<id>io.github.goabonga.shomer-cli</id>" in body
    assert "<icon type=\"stock\">shomer</icon>" in body


def test_hicolor_icon_installed() -> None:
    from pathlib import Path

    icon = Path("/usr/share/icons/hicolor/scalable/apps/shomer.svg")
    assert icon.is_file(), f"missing {icon}"
    assert icon.read_text().lstrip().startswith("<?xml")
