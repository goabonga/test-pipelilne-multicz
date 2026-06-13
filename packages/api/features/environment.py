# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Behave hooks for the shomer-api BDD suite.

Reads `SHOMER_API_URL` from the environment so the same .feature files
run against either a local `uv run shomer-api` (default
http://localhost:8000) or the kind-deployed instance the CI e2e-api
job port-forwards onto the same address. The base URL ends up on
``context.base_url`` and the shared httpx client on
``context.client``; step files use those rather than re-resolving env
in each step.
"""

from __future__ import annotations

import os

import httpx


def before_all(context):  # noqa: ANN001 — behave fixes this signature
    context.base_url = os.environ.get("SHOMER_API_URL", "http://localhost:8000")
    context.client = httpx.Client(base_url=context.base_url, timeout=10.0)


def after_all(context):  # noqa: ANN001 — behave fixes this signature
    client = getattr(context, "client", None)
    if client is not None:
        client.close()
