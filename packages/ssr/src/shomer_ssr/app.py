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
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.responses import Response
from starlette.types import Scope

from . import __version__

# Both directories are populated by `packages/web` at build
# time — never edit them directly; edit the upstream sources and run
# `npm --prefix packages/web run build`.
TEMPLATES_DIR = Path(__file__).parent / "templates"
STATIC_DIR = Path(__file__).parent / "static"
templates = Jinja2Templates(directory=str(TEMPLATES_DIR))


def frontend_config() -> dict[str, str]:
    """Runtime config handed to the React islands.

    Serialised into a ``<script id="app-config" type="application/json">``
    tag by ``base.html`` (``{{ config | tojson }}``) and read at mount
    time by ``packages/web/src/config.ts``. The server stays the single
    source of truth — nothing here is duplicated in the JS bundle.
    """
    return {
        "appName": "Shomer",
        "version": __version__,
        "loginAction": "/login",
    }


class DevAwareStaticFiles(StaticFiles):
    """``StaticFiles`` subclass that advertises sibling ``.map`` files
    via the ``SourceMap`` response header when one exists on disk.

    Using the header rather than the conventional
    ``//# sourceMappingURL=`` trailing comment keeps main.js / main.css
    byte-identical between dev and release, so a stray dev rebuild
    can't slip a dev-only marker into a release commit. The web
    container's ``--watch`` build writes ``main.js.map`` next to
    ``main.js`` (esbuild ``sourcemap: "external"``, no comment
    appended); release builds don't, so this branch silently no-ops
    in prod.

    Chrome / Firefox / Safari devtools treat the ``SourceMap``
    response header as equivalent to the in-bundle comment, so the
    debug experience is identical.
    """

    async def get_response(self, path: str, scope: Scope) -> Response:
        response = await super().get_response(path, scope)
        # `self.directory` is typed `str | PathLike[str] | None` on the
        # parent because StaticFiles also supports the `packages=`
        # initialiser; in our case the constructor below always passes
        # a real directory, so the None branch is unreachable in
        # practice but kept to satisfy --strict mypy.
        if (
            response.status_code == 200
            and path.endswith((".js", ".css"))
            and self.directory is not None
        ):
            map_path = Path(self.directory) / f"{path}.map"
            if map_path.is_file():
                response.headers["SourceMap"] = f"/static/{path}.map"
        return response


app = FastAPI(title="Shomer SSR", version=__version__)
app.mount("/static", DevAwareStaticFiles(directory=str(STATIC_DIR)), name="static")


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok", "version": __version__}


@app.post("/login")
def login_submit(
    username: str = Form(...),
    password: str = Form(...),
) -> JSONResponse:
    # Stub auth — always succeeds. The SPA POSTs here, then navigates
    # home client-side on the 200. A follow-up wires a real cookie-
    # session flow against shomer-api.
    _ = (username, password)
    return JSONResponse({"status": "ok"})


@app.get("/{full_path:path}", response_class=HTMLResponse)
def spa(request: Request, full_path: str) -> HTMLResponse:
    # Single-page app: every client route (``/``, ``/login``, deep
    # links, refreshes) is served the same Jinja shell, which injects
    # the runtime config; React Router renders the matching view. The
    # ``/static`` mount and ``/healthz`` are registered earlier, so
    # they never fall through to this catch-all.
    _ = full_path
    return templates.TemplateResponse(
        request, "index.html", {"version": __version__, "config": frontend_config()}
    )


def run() -> None:
    """Console-script entrypoint (``shomer-ssr``).

    Re-exported via ``[project.scripts] shomer-ssr`` in pyproject; the
    Helm chart, the .deb systemd unit and the local
    ``docker compose run ssr`` all converge here.
    """
    import uvicorn

    # Container / systemd service must listen on all interfaces.
    uvicorn.run("shomer_ssr.app:app", host="0.0.0.0", port=8080)  # nosec B104
