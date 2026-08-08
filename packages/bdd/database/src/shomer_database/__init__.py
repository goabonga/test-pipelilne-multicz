# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Shomer database layer: SQLAlchemy models, an injectable connector
(postgres / mysql / mssql) and Alembic migrations."""

from shomer_database.config import DatabaseSettings, Dialect
from shomer_database.engine import build_url, create_engine_from_settings
from shomer_database.models import Base
from shomer_database.session import Database

__version__ = "0.2.0"

__all__ = [
    "Base",
    "Database",
    "DatabaseSettings",
    "Dialect",
    "__version__",
    "build_url",
    "create_engine_from_settings",
]
