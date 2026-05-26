# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Minimal Jinja2-rendered Shomer frontend.

Three routes to keep the demo runnable:

* ``GET /healthz`` — liveness probe (Helm / systemd target).
* ``GET /`` — rendered home page (placeholder, no auth).
* ``GET /login`` and ``POST /login`` — login form. The POST handler
  is intentionally a stub today; a follow-up will wire cookie-based
  session auth against the ``shomer-api`` ``/oauth2/token`` endpoint.
"""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from . import __version__

# Both directories are populated by `packages/web` at build
# time — never edit them directly; edit the upstream sources and run
# `npm --prefix packages/web run build`.
TEMPLATES_DIR = Path(__file__).parent / "templates"
STATIC_DIR = Path(__file__).parent / "static"
templates = Jinja2Templates(directory=str(TEMPLATES_DIR))

app = FastAPI(title="Shomer SSR", version=__version__)
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok", "version": __version__}


@app.get("/", response_class=HTMLResponse)
def home(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(request, "home.html", {"version": __version__})


@app.get("/login", response_class=HTMLResponse)
def login_form(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(
        request, "login.html", {"version": __version__, "error": None}
    )


@app.post("/login")
def login_submit(
    username: str = Form(...),
    password: str = Form(...),
) -> RedirectResponse:
    # Cookie-based session auth lands in a follow-up — this stub
    # always succeeds and redirects home so the form is wired
    # end-to-end (template + POST handler + redirect).
    _ = (username, password)
    return RedirectResponse(url="/", status_code=303)


def run() -> None:
    """Console-script entrypoint (``shomer-ssr``)."""
    import uvicorn

    # Container / systemd service must listen on all interfaces.
    uvicorn.run("shomer_ssr.app:app", host="0.0.0.0", port=8080)  # noqa: S104  # nosec B104
