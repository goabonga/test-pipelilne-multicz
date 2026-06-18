# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

import pytest
from sqlalchemy import text

from shomer_database import Database, DatabaseSettings, build_url


@pytest.mark.parametrize(
    ("dialect", "expected_driver"),
    [
        ("postgresql", "postgresql+psycopg"),
        ("mysql", "mysql+pymysql"),
        ("mssql", "mssql+pyodbc"),
    ],
)
def test_build_url_selects_driver(dialect: str, expected_driver: str) -> None:
    url = build_url(
        DatabaseSettings(
            dialect=dialect, host="db", username="u", password="p", database="shomer"
        )  # type: ignore[arg-type]
    )
    assert url.drivername == expected_driver
    assert url.host == "db"
    assert url.database == "shomer"


def test_build_url_applies_default_port() -> None:
    assert build_url(DatabaseSettings(dialect="postgresql")).port == 5432
    assert build_url(DatabaseSettings(dialect="mysql")).port == 3306
    assert build_url(DatabaseSettings(dialect="mssql")).port == 1433


def test_full_url_overrides_assembly() -> None:
    url = build_url(DatabaseSettings(dialect="postgresql", url="sqlite:///x.db"))
    assert url.drivername == "sqlite"


def test_from_env_url_short_circuits(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SHOMER_BDD_URL", "mysql+pymysql://u:p@h/shomer")
    settings = DatabaseSettings.from_env()
    assert settings.dialect == "mysql"
    assert build_url(settings).host == "h"


def test_database_session_connects() -> None:
    # sqlite in-memory exercises the connector + session without a real server.
    db = Database(DatabaseSettings(dialect="postgresql", url="sqlite://"))
    with db.session() as session:
        assert session.execute(text("select 1")).scalar() == 1
    db.dispose()
