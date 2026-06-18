# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

import signal

import pytest

from shomer_job import main


def test_tick_runs_without_raising() -> None:
    main.tick()  # logs at INFO; just verify no exception


def test_run_calls_tick_max_iterations_times(monkeypatch: pytest.MonkeyPatch) -> None:
    """``run(max_iterations=N)`` must call ``tick()`` exactly N times,
    sleep N-1 times (the last sleep is short-circuited by the break),
    and SystemExit(0)."""
    ticks: list[int] = []
    sleeps: list[float] = []
    # `tick` now takes an iteration index (1-based) so the polling
    # loop's log line is observable in production. The test only
    # cares about how many times it was called, not the index.
    monkeypatch.setattr(main, "tick", lambda i: ticks.append(i))

    with pytest.raises(SystemExit) as exc:
        main.run(
            interval_seconds=0.0,
            sleep=lambda s: sleeps.append(s),
            max_iterations=3,
        )
    assert exc.value.code == 0
    assert ticks == [1, 2, 3]
    assert sleeps == [0.0, 0.0]


def test_run_uses_injected_sleep_interval(monkeypatch: pytest.MonkeyPatch) -> None:
    sleeps: list[float] = []
    monkeypatch.setattr(main, "tick", lambda _i: None)
    with pytest.raises(SystemExit):
        main.run(
            interval_seconds=2.5,
            sleep=lambda s: sleeps.append(s),
            max_iterations=2,
        )
    assert sleeps == [2.5]


def test_run_stops_on_signal(monkeypatch: pytest.MonkeyPatch) -> None:
    """The injected sleep fires the registered SIGTERM handler, exercising
    the _on_signal callback (stop = True) and the stop-driven loop exit."""
    monkeypatch.setattr(main, "tick", lambda _i: None)

    def fake_sleep(_seconds: float) -> None:
        handler = signal.getsignal(signal.SIGTERM)
        handler(signal.SIGTERM, None)  # type: ignore[operator]

    with pytest.raises(SystemExit) as exc:
        main.run(interval_seconds=0.0, sleep=fake_sleep)
    assert exc.value.code == 0
