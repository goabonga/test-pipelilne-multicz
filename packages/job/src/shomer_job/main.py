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

from celery import Celery  # type: ignore[import-untyped]

from . import __version__

log = logging.getLogger("shomer.job")

# Broker + result backend. Override REDIS_URL to point at a managed
# Redis; the systemd unit and docker-compose both set it.
REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")

app = Celery("shomer-job", broker=REDIS_URL, backend=REDIS_URL)

# Wait for the broker instead of dying when it is not up yet.
#
# Left unset, Celery 5 warns on every start that this default will flip in
# 6.0, and once it does a worker that boots before Redis is ready exits
# rather than retrying. That is the normal case on a cold start: compose
# and Kubernetes both bring the worker up alongside Redis, not after it.
# Pinning it here makes the behaviour the deployment needs explicit
# instead of inherited, and silences a warning that would otherwise be
# ignored until the day it stops being one.
app.conf.broker_connection_retry_on_startup = True

# Fire `tick` once a minute. Embedded beat (`worker --beat`) drives this
# in the single-worker skeleton; a real deployment would run a dedicated
# `celery beat` process instead.
app.conf.beat_schedule = {
    "shomer-job-tick": {"task": "shomer_job.tick", "schedule": 60.0},
}

# Embedded beat persists a small schedule DB (last-run timestamps). Its
# default location is the CWD, which isn't writable when the worker runs
# as a non-root user — the docker-compose dev container and the systemd
# unit both do. Point it at a writable path; override with
# CELERYBEAT_SCHEDULE if a deployment wants durable state on a volume.
app.conf.beat_schedule_filename = os.environ.get(
    "CELERYBEAT_SCHEDULE",
    "/tmp/celerybeat-schedule",  # nosec B108
)


@app.task(name="shomer_job.tick")  # type: ignore[untyped-decorator]
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
