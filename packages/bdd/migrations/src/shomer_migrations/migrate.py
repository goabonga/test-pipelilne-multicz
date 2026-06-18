# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Apply Alembic migrations — ``alembic upgrade head``.

Console entrypoint ``shomer-migrate`` used by the migration Job. Locates the
revisions packaged inside ``shomer_migrations``, resolves the URL from the
``SHOMER_BDD_*`` environment (via env.py) and applies only the pending
revisions. It never recreates the database.
"""

from __future__ import annotations

import sys
from importlib.resources import files

from alembic import command
from alembic.config import Config


def _config() -> Config:
    cfg = Config()
    cfg.set_main_option(
        "script_location", str(files("shomer_migrations") / "migrations")
    )
    return cfg


def upgrade(revision: str = "head") -> None:
    """Apply pending migrations up to ``revision`` (default ``head``)."""
    command.upgrade(_config(), revision)


def main() -> None:
    upgrade(sys.argv[1] if len(sys.argv) > 1 else "head")
