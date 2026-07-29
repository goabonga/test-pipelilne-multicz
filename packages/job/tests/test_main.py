# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

import pytest
from shomer_job import main


def test_app_is_configured_for_redis() -> None:
    """Broker and result backend both point at Redis."""
    assert main.app.main == "shomer-job"
    assert main.app.conf.broker_url.startswith("redis://")
    assert main.app.conf.result_backend.startswith("redis://")


def test_tick_is_scheduled_every_minute() -> None:
    entry = main.app.conf.beat_schedule["shomer-job-tick"]
    assert entry["task"] == "shomer_job.tick"
    assert entry["schedule"] == 60.0


def test_tick_runs_and_returns_status() -> None:
    """Calling the task directly runs the body in-process (no broker)
    and returns a status string carrying the version."""
    result = main.tick()
    assert main.__version__ in result


def test_run_boots_worker_with_embedded_beat(monkeypatch: pytest.MonkeyPatch) -> None:
    """``run()`` hands a ``worker --beat`` argv to Celery rather than
    connecting to a live broker."""
    captured: list[str] = []
    monkeypatch.setattr(main.app, "worker_main", lambda argv: captured.extend(argv))

    main.run()

    assert captured[0] == "worker"
    assert "--beat" in captured
