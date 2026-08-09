# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Validate the installed `shomer-migrations` Debian package.

Note: the console-script is `shomer-migrate` (not `shomer-migrations`) —
defined in `packages/bdd/migrations/pyproject.toml#project.scripts`.

This package exists so a host install of shomer-api / shomer-job /
shomer-ssr has a way to create and migrate its schema: those packages
carry none of their own."""

from __future__ import annotations

import shutil
from pathlib import Path

UNIT = Path("/usr/lib/systemd/system/shomer-migrations.service")


def test_console_script_on_path() -> None:
    assert shutil.which("shomer-migrate"), "shomer-migrate console-script missing from PATH"


def test_module_imports_and_version_matches(run, system_python, versions) -> None:
    out = run(
        system_python,
        "-c",
        "import shomer_migrations; print(shomer_migrations.__version__)",
    )
    installed = out.stdout.strip()
    expected = versions["migrations"]
    assert installed == expected, (
        f"installed shomer_migrations.__version__ = {installed!r} but VERSION says {expected!r}"
    )


def test_alembic_revisions_are_packaged(run, system_python) -> None:
    """The revisions are the payload. A package that installs the runner
    but not the migrations would pass every other check here and then do
    nothing on a real host."""
    out = run(
        system_python,
        "-c",
        "import shomer_migrations, pathlib;"
        "p = pathlib.Path(shomer_migrations.__file__).parent / 'versions';"
        "print(len(list(p.glob('*.py'))))",
    )
    assert int(out.stdout.strip()) > 0, "no alembic revisions found beside the installed package"


def test_systemd_unit_installed() -> None:
    assert UNIT.is_file(), f"missing {UNIT}"


def test_unit_is_oneshot() -> None:
    body = UNIT.read_text()
    assert "Type=oneshot" in body, "the migration unit must not be a long-running service"


def test_unit_cannot_be_enabled() -> None:
    """No `[Install]` section, deliberately.

    `systemctl enable` has nothing to hook onto, so the unit cannot start
    at boot and apt cannot migrate a database as a side effect of
    installing a package. If someone adds `[Install]` later, this fails
    and they have to argue for it."""
    body = UNIT.read_text()
    assert "[Install]" not in body, (
        "shomer-migrations.service declares [Install]: installing the package "
        "would let systemd run migrations unattended"
    )
