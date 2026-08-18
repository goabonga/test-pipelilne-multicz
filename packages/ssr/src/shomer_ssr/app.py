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
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse
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

# Generated from assets/shomer.svg by scripts/regen-icons.sh, and committed
# like the rest of static/ — the wheel ships whatever is on disk at build
# time, so a favicon that only exists after someone runs a script is a
# favicon missing from the release.
FAVICON = STATIC_DIR / "favicon.ico"
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


# docs_url=None disables FastAPI's built-in /docs so the route below can
# replace it. There is no way to pass a favicon to the built-in one — the
# only lever is swagger_favicon_url, which means owning the route.
app = FastAPI(title="Shomer SSR", version=__version__, docs_url=None)
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


# BEFORE THE CATCH-ALL, and that ordering is the whole reason this route
# exists as code rather than as a file in static/.
#
# Browsers request /favicon.ico at the root on their own, without being
# told to. Without this, that request falls through to the SPA handler
# below and receives an HTML document with a 200 — so the browser gets a
# successful response that is not an image, shows no icon, and gives
# nothing to diagnose. A 404 would at least be legible; a 200 of the wrong
# type is not.
@app.get("/favicon.ico", include_in_schema=False)
def favicon() -> FileResponse:
    # Long max-age: the icon changes when the brand does, which is roughly
    # never, and a browser re-requesting it on every navigation is the
    # single most pointless request a site makes.
    return FileResponse(
        FAVICON,
        media_type="image/x-icon",
        headers={"Cache-Control": "public, max-age=604800, immutable"},
    )


@app.get("/docs", include_in_schema=False)
def swagger_ui() -> HTMLResponse:
    # Registered before the catch-all for the same reason as the favicon:
    # otherwise /docs is a client route as far as the SPA handler is
    # concerned, and returns the app shell instead of the documentation.
    return get_swagger_ui_html(
        openapi_url=app.openapi_url or "/openapi.json",
        title=f"{app.title} — API docs",
        swagger_favicon_url="/favicon.ico",
        # Vendored, not from jsdelivr. The default URLs make every reader
        # of this page fetch 1.5 MB of executable code from a third party,
        # which is a dependency nothing else here accepts silently — and
        # it renders as an unstyled page with no error in exactly the
        # private network this is deployed into.
        #
        # scripts/vendor-swagger.py fetches and pins them; CI verifies the
        # hashes.
        swagger_js_url="/static/swagger/swagger-ui-bundle.js",
        swagger_css_url="/static/swagger/swagger-ui.css",
    )


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
