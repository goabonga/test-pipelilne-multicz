# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Validate the installed `shomer-ssr` Debian package — including the
Jinja2 templates + bundled CSS/JS, which are easy to drop on the floor
during dh-python's source-to-package translation."""

from __future__ import annotations

import shutil


def test_console_script_on_path() -> None:
    assert shutil.which("shomer-ssr"), "shomer-ssr console-script missing from PATH"


def test_module_imports(run, system_python) -> None:
    out = run(
        system_python,
        "-c",
        "import shomer_ssr; print(shomer_ssr.__version__)",
    )
    assert out.stdout.strip()


def test_module_version_matches_bumped_value(run, system_python, versions) -> None:
    out = run(
        system_python,
        "-c",
        "import shomer_ssr; print(shomer_ssr.__version__)",
    )
    installed = out.stdout.strip()
    expected = versions["ssr"]
    assert installed == expected, (
        f"installed shomer_ssr.__version__ = {installed!r} but VERSION says {expected!r}"
    )


def test_fastapi_app_object_loads(run, system_python) -> None:
    out = run(
        system_python,
        "-c",
        "from shomer_ssr.app import app; print(app.title)",
    )
    assert out.stdout.strip(), "shomer_ssr.app.app resolved to a falsy object"


def test_packaged_resources_present(run, system_python) -> None:
    """Templates and built static assets must travel with the .deb —
    a missing `templates/` or `static/main.css` is the most common
    pybuild regression for a Jinja+frontend hybrid."""
    out = run(
        system_python,
        "-c",
        (
            "from importlib.resources import files;"
            "root = files('shomer_ssr');"
            "names = sorted(p.name for p in root.iterdir());"
            "print(' '.join(names))"
        ),
    )
    listing = out.stdout
    assert "templates" in listing, f"templates dir missing from package: {listing!r}"
    assert "static" in listing, f"static dir missing from package: {listing!r}"


def test_appstream_metainfo_installed() -> None:
    from pathlib import Path

    metainfo = Path("/usr/share/metainfo/shomer-ssr.metainfo.xml")
    assert metainfo.is_file(), f"missing {metainfo}"
    body = metainfo.read_text()
    assert "<id>io.github.goabonga.shomer-ssr</id>" in body
    assert "<icon type=\"stock\">shomer-ssr</icon>" in body


def test_hicolor_icon_installed() -> None:
    from pathlib import Path

    icon = Path("/usr/share/icons/hicolor/scalable/apps/shomer-ssr.svg")
    assert icon.is_file(), f"missing {icon}"
    assert icon.read_text().lstrip().startswith("<?xml")
