# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Behave hooks for the shomer-ssr BDD suite.

Two parallel surfaces live on each context:

* ``context.client`` — an ``httpx.Client`` for the HTTP-only
  scenarios in health.feature (status code + JSON shape).
* ``context.page`` — a Playwright ``Page`` opened on a fresh browser
  context per scenario. Drives the ui.feature flows so the rendered
  DOM (Jinja templates served by FastAPI) and the login redirect
  chain (POST /login -> 303 -> GET /) get exercised through a real
  Chromium head.

Both target the same base URL, read once from ``SHOMER_SSR_URL``
(default ``http://localhost:8080``) — which is what the CI e2e-ssr
job port-forwards onto from the kind cluster.

Browser lifecycle:

* ``before_all`` launches Playwright once and the Chromium head once.
* ``before_scenario`` opens a fresh browser context + page so cookies
  / localStorage don't leak across scenarios.
* ``after_scenario`` and ``after_all`` clean up in reverse order so
  Playwright's resource accounting stays balanced.
"""

from __future__ import annotations

import os

import httpx
from playwright.sync_api import sync_playwright


def before_all(context):  # noqa: ANN001
    context.base_url = os.environ.get("SHOMER_SSR_URL", "http://localhost:8080")
    context.client = httpx.Client(base_url=context.base_url, timeout=10.0)
    context.playwright = sync_playwright().start()
    context.browser = context.playwright.chromium.launch()


def before_scenario(context, scenario):  # noqa: ANN001, ARG001
    context.browser_context = context.browser.new_context(base_url=context.base_url)
    context.page = context.browser_context.new_page()


def after_scenario(context, scenario):  # noqa: ANN001, ARG001
    page = getattr(context, "page", None)
    if page is not None:
        page.close()
    browser_context = getattr(context, "browser_context", None)
    if browser_context is not None:
        browser_context.close()


def after_all(context):  # noqa: ANN001
    client = getattr(context, "client", None)
    if client is not None:
        client.close()
    browser = getattr(context, "browser", None)
    if browser is not None:
        browser.close()
    pw = getattr(context, "playwright", None)
    if pw is not None:
        pw.stop()
