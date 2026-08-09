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


def test_alembic_tree_is_packaged(run, system_python) -> None:
    """The alembic tree is the payload. A wheel that ships only the
    runner would pass every other check here and then fail on a real
    host with "No 'script_location' directory".

    Note what this does NOT assert: the number of revisions. There are
    none yet — `versions/` holds a .gitkeep — and a revision count is a
    statement about the project's schema history, not about whether the
    package was built correctly. Asserting it here failed the build for
    a reason that had nothing to do with packaging."""
    out = run(
        system_python,
        "-c",
        "import shomer_migrations, pathlib;"
        "root = pathlib.Path(shomer_migrations.__file__).parent / 'migrations';"
        "print(int((root / 'env.py').is_file()),"
        " int((root / 'script.py.mako').is_file()),"
        " int((root / 'versions').is_dir()))",
    )
    env_py, mako, versions = out.stdout.split()
    assert env_py == "1", "migrations/env.py missing — alembic has no environment to run in"
    assert mako == "1", "migrations/script.py.mako missing — `alembic revision` would fail"
    assert versions == "1", "migrations/versions/ missing — nowhere for revisions to live"


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
    # Line-anchored, not a substring search. The unit's own comment
    # explains why there is no such section, and a naive `"[Install]" in
    # body` matched that comment and failed the build — a test fooled by
    # prose is worse than no test.
    sections = [line.strip() for line in UNIT.read_text().splitlines()
                if line.strip().startswith("[") and line.strip().endswith("]")]
    assert "[Install]" not in sections, (
        "shomer-migrations.service declares an [Install] section: installing "
        "the package would let systemd run migrations unattended"
    )
