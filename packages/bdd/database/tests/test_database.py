# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

import pytest
from shomer_database import Database, DatabaseSettings, build_url
from sqlalchemy import text


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


def test_from_env_assembles_from_fields(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("SHOMER_BDD_URL", raising=False)
    monkeypatch.setenv("SHOMER_BDD_DIALECT", "postgresql")
    monkeypatch.setenv("SHOMER_BDD_HOST", "pg")
    monkeypatch.setenv("SHOMER_BDD_PORT", "6543")
    monkeypatch.setenv("SHOMER_BDD_USERNAME", "u")
    monkeypatch.setenv("SHOMER_BDD_PASSWORD", "p")
    monkeypatch.setenv("SHOMER_BDD_DATABASE", "shomer")
    settings = DatabaseSettings.from_env()
    assert settings.dialect == "postgresql"
    assert settings.host == "pg"
    assert settings.resolved_port == 6543
    url = build_url(settings)
    assert url.username == "u"
    assert url.database == "shomer"


def test_from_env_defaults(monkeypatch: pytest.MonkeyPatch) -> None:
    for key in ("URL", "DIALECT", "HOST", "PORT", "USERNAME", "PASSWORD", "DATABASE"):
        monkeypatch.delenv(f"SHOMER_BDD_{key}", raising=False)
    settings = DatabaseSettings.from_env()
    assert settings.dialect == "postgresql"
    assert settings.host == "localhost"
    assert settings.resolved_port == 5432


def test_from_env_rejects_unknown_dialect(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("SHOMER_BDD_URL", raising=False)
    monkeypatch.setenv("SHOMER_BDD_DIALECT", "oracle")
    with pytest.raises(ValueError, match="DIALECT"):
        DatabaseSettings.from_env()


def test_database_session_connects() -> None:
    # sqlite in-memory exercises the connector + session without a real server.
    db = Database(DatabaseSettings(dialect="postgresql", url="sqlite://"))
    with db.session() as session:
        assert session.execute(text("select 1")).scalar() == 1
    db.dispose()


def test_database_from_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SHOMER_BDD_URL", "sqlite://")
    db = Database.from_env()
    with db.session() as session:
        assert session.execute(text("select 1")).scalar() == 1
    db.dispose()


def test_session_rolls_back_on_error() -> None:
    db = Database(DatabaseSettings(dialect="postgresql", url="sqlite://"))
    with pytest.raises(RuntimeError, match="boom"), db.session():
        raise RuntimeError("boom")
    db.dispose()


def test_get_session_yields_and_closes() -> None:
    db = Database(DatabaseSettings(dialect="postgresql", url="sqlite://"))
    gen = db.get_session()
    session = next(gen)
    assert session.execute(text("select 1")).scalar() == 1
    gen.close()  # triggers the finally: session.close()
    db.dispose()


def test_get_session_rolls_back_on_error() -> None:
    """A failed transaction must not go back to the pool unresolved.

    `session()` already rolled back; `get_session()` did not, so a request
    that raised mid-transaction returned a session in a failed state and
    the next borrower met PendingRollbackError on its first statement.
    """
    db = Database(DatabaseSettings(dialect="postgresql", url="sqlite://"))
    gen = db.get_session()
    session = next(gen)
    session.execute(text("select 1"))

    with pytest.raises(RuntimeError, match="boom"):
        gen.throw(RuntimeError("boom"))

    # rollback() left nothing pending, so the session is reusable.
    assert not session.in_transaction()
    db.dispose()
