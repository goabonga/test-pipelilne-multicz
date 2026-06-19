# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Shomer background jobs — a Celery worker backed by Redis.

Real work (purging expired refresh tokens, replicating audit events to
a SIEM, …) is modelled as Celery tasks. Both the broker and the result
backend are Redis, configured from ``REDIS_URL`` (default
``redis://localhost:6379/0`` — the docker-compose ``redis`` service and
the systemd unit both inject it).

``run()`` is the console-script entrypoint: it boots a worker with an
embedded beat scheduler so the periodic ``tick`` fires without a
standalone ``celery beat`` process.
"""

from __future__ import annotations

import logging
import os

from celery import Celery

from . import __version__

log = logging.getLogger("shomer.job")

# Broker + result backend. Override REDIS_URL to point at a managed
# Redis; the systemd unit and docker-compose both set it.
REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")

app = Celery("shomer-job", broker=REDIS_URL, backend=REDIS_URL)

# Fire `tick` once a minute. Embedded beat (`worker --beat`) drives this
# in the single-worker skeleton; a real deployment would run a dedicated
# `celery beat` process instead.
app.conf.beat_schedule = {
    "shomer-job-tick": {"task": "shomer_job.tick", "schedule": 60.0},
}


@app.task(name="shomer_job.tick")
def tick() -> str:
    """One maintenance pass. Replace with real work.

    Returns a short status string so the Redis result backend has
    something to store (and tests have something to assert on).
    """
    log.info("shomer.job tick (v%s)", __version__)
    return f"shomer-job tick ok (v{__version__})"


def run() -> None:
    """Console-script entrypoint (``shomer-job``).

    Boots a Celery worker with embedded beat so the periodic schedule
    above runs without a separate ``celery beat`` process.
    """
    app.worker_main(argv=["worker", "--loglevel=INFO", "--beat"])
