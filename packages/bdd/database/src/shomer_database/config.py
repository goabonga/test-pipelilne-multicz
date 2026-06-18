# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Database connection settings.

The connector is selected by ``dialect`` — ``postgresql``, ``mysql`` or
``mssql`` — so the engine that gets built (and therefore the driver that gets
injected) is decided by configuration, not hard-coded at the call site. Build
settings explicitly or from the environment with :meth:`DatabaseSettings.from_env`.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Literal

Dialect = Literal["postgresql", "mysql", "mssql"]

DEFAULT_PORTS: dict[str, int] = {
    "postgresql": 5432,
    "mysql": 3306,
    "mssql": 1433,
}


@dataclass(frozen=True)
class DatabaseSettings:
    """Connection settings for a single database.

    Either provide the individual fields, or pass a fully-formed ``url`` to
    bypass assembly entirely (it then takes precedence over everything else).
    """

    dialect: Dialect
    host: str = "localhost"
    port: int | None = None
    username: str | None = None
    password: str | None = None
    database: str | None = None
    query: dict[str, str] = field(default_factory=dict)
    url: str | None = None

    @property
    def resolved_port(self) -> int | None:
        return self.port if self.port is not None else DEFAULT_PORTS.get(self.dialect)

    @classmethod
    def from_env(cls, prefix: str = "SHOMER_BDD_") -> DatabaseSettings:
        """Build settings from ``{prefix}*`` environment variables.

        ``{prefix}URL`` short-circuits everything. Otherwise reads
        ``{prefix}DIALECT`` / ``HOST`` / ``PORT`` / ``USERNAME`` / ``PASSWORD``
        / ``DATABASE``.
        """
        url = os.environ.get(f"{prefix}URL")
        if url:
            # dialect is still required by the type but unused when url is set;
            # infer it from the scheme prefix for completeness.
            scheme = url.split(":", 1)[0].split("+", 1)[0]
            dialect: Dialect = scheme if scheme in DEFAULT_PORTS else "postgresql"  # type: ignore[assignment]
            return cls(dialect=dialect, url=url)

        dialect_env = os.environ.get(f"{prefix}DIALECT", "postgresql")
        if dialect_env not in DEFAULT_PORTS:
            raise ValueError(
                f"{prefix}DIALECT must be one of {sorted(DEFAULT_PORTS)}, got {dialect_env!r}"
            )
        port = os.environ.get(f"{prefix}PORT")
        return cls(
            dialect=dialect_env,  # type: ignore[arg-type]
            host=os.environ.get(f"{prefix}HOST", "localhost"),
            port=int(port) if port else None,
            username=os.environ.get(f"{prefix}USERNAME"),
            password=os.environ.get(f"{prefix}PASSWORD"),
            database=os.environ.get(f"{prefix}DATABASE"),
        )
