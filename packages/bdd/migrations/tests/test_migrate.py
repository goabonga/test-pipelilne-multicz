# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

import sys
from pathlib import Path

import pytest

from shomer_migrations import __version__, migrate
from shomer_migrations.migrate import _config


def test_version_is_string() -> None:
    assert isinstance(__version__, str)


def test_config_points_at_packaged_migrations() -> None:
    # The runner must resolve the revisions shipped inside the wheel.
    location = _config().get_main_option("script_location")
    assert location is not None
    assert (Path(location) / "env.py").is_file()


def test_upgrade_invokes_alembic(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[tuple[object, str]] = []
    monkeypatch.setattr(
        migrate.command, "upgrade", lambda cfg, rev: calls.append((cfg, rev))
    )
    migrate.upgrade("head")
    assert len(calls) == 1
    cfg, rev = calls[0]
    assert rev == "head"
    location = cfg.get_main_option("script_location")  # type: ignore[attr-defined]
    assert (Path(location) / "env.py").is_file()


def test_main_defaults_to_head(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: list[str] = []
    monkeypatch.setattr(migrate, "upgrade", lambda rev="head": captured.append(rev))
    monkeypatch.setattr(sys, "argv", ["shomer-migrate"])
    migrate.main()
    assert captured == ["head"]


def test_main_passes_revision(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: list[str] = []
    monkeypatch.setattr(migrate, "upgrade", lambda rev="head": captured.append(rev))
    monkeypatch.setattr(sys, "argv", ["shomer-migrate", "abc123"])
    migrate.main()
    assert captured == ["abc123"]
