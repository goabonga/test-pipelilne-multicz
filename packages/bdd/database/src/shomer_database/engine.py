# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Build a SQLAlchemy URL / engine from :class:`DatabaseSettings`.

Each dialect maps to a concrete driver; install the matching extra
(``shomer-bdd[postgres|mysql|mssql]``) for the one you use.
"""

from __future__ import annotations

from typing import Any

from sqlalchemy import URL, Engine, create_engine, make_url

from shomer_database.config import DatabaseSettings

# dialect -> SQLAlchemy "dialect+driver" string.
DRIVERS: dict[str, str] = {
    "postgresql": "postgresql+psycopg",  # psycopg 3 (shomer-bdd[postgres])
    "mysql": "mysql+pymysql",  # PyMySQL (shomer-bdd[mysql])
    "mssql": "mssql+pyodbc",  # pyodbc (shomer-bdd[mssql])
}


def build_url(settings: DatabaseSettings) -> URL:
    """Assemble the SQLAlchemy ``URL`` for ``settings``.

    A full ``settings.url`` overrides field-by-field assembly.
    """
    if settings.url:
        return make_url(settings.url)
    return URL.create(
        DRIVERS[settings.dialect],
        username=settings.username,
        password=settings.password,
        host=settings.host,
        port=settings.resolved_port,
        database=settings.database,
        query=settings.query,
    )


def create_engine_from_settings(settings: DatabaseSettings, **kwargs: Any) -> Engine:
    """Create a SQLAlchemy :class:`~sqlalchemy.Engine` for ``settings``.

    Extra ``kwargs`` are forwarded to :func:`sqlalchemy.create_engine`
    (``pool_size``, ``echo``, ...).
    """
    return create_engine(build_url(settings), **kwargs)
