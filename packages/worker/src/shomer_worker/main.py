"""Minimal polling loop.

Real implementations would purge expired refresh tokens, replicate
audit events to a SIEM, etc. The skeleton just ticks once a minute
with an injectable sleep so tests can drive it without waiting.
"""

from __future__ import annotations

import logging
import signal
import sys
import time
from collections.abc import Callable

from . import __version__

log = logging.getLogger("shomer.worker")


def tick() -> None:
    """One iteration of the work loop. Replace with real work."""
    log.info("shomer.worker tick (v%s)", __version__)


def run(
    *,
    interval_seconds: float = 60.0,
    sleep: Callable[[float], None] = time.sleep,
    max_iterations: int | None = None,
) -> None:
    """Console-script entrypoint (``shomer-worker``).

    ``max_iterations`` and ``sleep`` are injected so tests can drive
    the loop deterministically without sleeping.
    """
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(message)s")
    log.info("shomer.worker starting (v%s, interval=%ss)", __version__, interval_seconds)

    stop = False

    def _on_signal(signum: int, _frame: object) -> None:
        nonlocal stop
        log.info("shomer.worker received signal %s, shutting down", signum)
        stop = True

    signal.signal(signal.SIGTERM, _on_signal)
    signal.signal(signal.SIGINT, _on_signal)

    iterations = 0
    while not stop:
        tick()
        iterations += 1
        if max_iterations is not None and iterations >= max_iterations:
            break
        sleep(interval_seconds)
    sys.exit(0)
