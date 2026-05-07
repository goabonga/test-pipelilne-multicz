# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

import pytest

from shomer_worker import main


def test_tick_runs_without_raising() -> None:
    main.tick()  # logs at INFO; just verify no exception


def test_run_calls_tick_max_iterations_times(monkeypatch: pytest.MonkeyPatch) -> None:
    """``run(max_iterations=N)`` must call ``tick()`` exactly N times,
    sleep N-1 times (the last sleep is short-circuited by the break),
    and SystemExit(0)."""
    ticks: list[int] = []
    sleeps: list[float] = []
    monkeypatch.setattr(main, "tick", lambda: ticks.append(1))

    with pytest.raises(SystemExit) as exc:
        main.run(
            interval_seconds=0.0,
            sleep=lambda s: sleeps.append(s),
            max_iterations=3,
        )
    assert exc.value.code == 0
    assert len(ticks) == 3
    assert sleeps == [0.0, 0.0]


def test_run_uses_injected_sleep_interval(monkeypatch: pytest.MonkeyPatch) -> None:
    sleeps: list[float] = []
    monkeypatch.setattr(main, "tick", lambda: None)
    with pytest.raises(SystemExit):
        main.run(
            interval_seconds=2.5,
            sleep=lambda s: sleeps.append(s),
            max_iterations=2,
        )
    assert sleeps == [2.5]
