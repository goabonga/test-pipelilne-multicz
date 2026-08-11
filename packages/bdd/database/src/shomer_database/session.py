# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Injectable database connector.

:class:`Database` wraps an engine and a session factory built from
:class:`DatabaseSettings`. Construct it once (from explicit settings or the
environment) and inject :meth:`Database.get_session` as a dependency — e.g.
``Depends(database.get_session)`` in FastAPI. Which backend you get
(postgres / mysql / mssql) is decided by the injected settings.
"""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager
from typing import Any

from sqlalchemy import Engine
from sqlalchemy.orm import Session, sessionmaker

from shomer_database.config import DatabaseSettings
from shomer_database.engine import create_engine_from_settings


class Database:
    """Engine + session factory for one configured database."""

    def __init__(self, settings: DatabaseSettings, **engine_kwargs: Any) -> None:
        self.settings = settings
        self.engine: Engine = create_engine_from_settings(settings, **engine_kwargs)
        self.session_factory = sessionmaker(bind=self.engine, expire_on_commit=False)

    @classmethod
    def from_env(cls, prefix: str = "SHOMER_BDD_", **engine_kwargs: Any) -> Database:
        return cls(DatabaseSettings.from_env(prefix), **engine_kwargs)

    @contextmanager
    def session(self) -> Iterator[Session]:
        """Context-managed session: commit on success, rollback on error."""
        session = self.session_factory()
        try:
            yield session
            session.commit()
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()

    def get_session(self) -> Iterator[Session]:
        """Dependency-injection provider (FastAPI ``Depends`` compatible).

        Yields a session and closes it afterwards; the caller commits.

        An exception raised by the caller rolls the session back before it
        is closed. Without that, a session whose transaction had already
        failed went back to the pool in that state, and the next request to
        borrow it met ``PendingRollbackError`` on its first statement —
        reported against a request that had done nothing wrong.
        """
        session = self.session_factory()
        try:
            yield session
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()

    def dispose(self) -> None:
        self.engine.dispose()
