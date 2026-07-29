# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Alembic environment for shomer-bdd.

Migrations live here (repo + migration image), NOT in the shomer-bdd wheel, so
consumers (api / job) that only need the models never pull Alembic or the
revisions. Resolves the URL (precedence: ``-x url=...`` > ``sqlalchemy.url`` >
``SHOMER_BDD_*`` env) and targets ``Base.metadata`` for ``--autogenerate``.
"""

from __future__ import annotations

from alembic import context
from shomer_database.config import DatabaseSettings
from shomer_database.engine import build_url
from shomer_database.models import Base
from sqlalchemy import engine_from_config, pool

config = context.config
target_metadata = Base.metadata


def _database_url() -> str:
    x_args = context.get_x_argument(as_dictionary=True)
    if "url" in x_args:
        return x_args["url"]
    configured = config.get_main_option("sqlalchemy.url")
    if configured:
        return configured
    return build_url(DatabaseSettings.from_env()).render_as_string(hide_password=False)


def run_migrations_offline() -> None:
    context.configure(
        url=_database_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    section = config.get_section(config.config_ini_section, {})
    section["sqlalchemy.url"] = _database_url()
    connectable = engine_from_config(
        section,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
