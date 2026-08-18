# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Minimal Shomer API surface.

Two endpoints to keep the demo runnable end-to-end:

* ``GET /healthz`` — liveness probe (Helm + systemd watchdog target).
* ``GET /.well-known/openid-configuration`` — OIDC discovery stub
  pointing at not-yet-implemented endpoints; gives downstream clients
  a deterministic JSON contract to read from in the meantime.
"""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles

from . import __version__

# Placeholder issuer URL until the deployed listener URL is wired
# through config — keeps the discovery JSON deterministic and the
# behave checks (which assert on `issuer`) stable.
OIDC_ISSUER = "http://localhost:8000"

# Generated from assets/shomer.svg by scripts/regen-icons.sh and committed,
# so the wheel ships it — a favicon that exists only after someone runs a
# script is a favicon missing from the release.
STATIC_DIR = Path(__file__).parent / "static"
FAVICON = STATIC_DIR / "favicon.ico"

# docs_url=None disables FastAPI's built-in /docs so the route below can
# replace it. There is no way to pass a favicon to the built-in one: the
# only lever is swagger_favicon_url on get_swagger_ui_html, which means
# owning the route.
app = FastAPI(title="Shomer API", version=__version__, docs_url=None)

# The api serves no HTML of its own; this mount exists solely so /docs can
# load its own Swagger UI rather than jsdelivr's. Narrow on purpose — it is
# not a general place to put files.
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


@app.get("/favicon.ico", include_in_schema=False)
def favicon() -> FileResponse:
    # Browsers request this at the root without being told to. The api
    # serves no HTML of its own, so without this route the request 404s on
    # every tab that has the docs open.
    return FileResponse(
        FAVICON,
        media_type="image/x-icon",
        headers={"Cache-Control": "public, max-age=604800, immutable"},
    )


@app.get("/docs", include_in_schema=False)
def swagger_ui() -> HTMLResponse:
    # Same Swagger UI FastAPI would have served, with one argument added.
    # Its JS and CSS still come from the CDN default, which is a browser
    # fetch rather than a server one — it does not pass the egress proxy
    # and is not affected by it.
    return get_swagger_ui_html(
        openapi_url=app.openapi_url or "/openapi.json",
        title=f"{app.title} — API docs",
        swagger_favicon_url="/favicon.ico",
        # Vendored, not from jsdelivr. The default URLs make every reader
        # of this page fetch 1.5 MB of executable code from a third party,
        # which is a dependency nothing else here accepts silently — and it
        # renders as an unstyled page with no error in exactly the private
        # network this is deployed into.
        #
        # scripts/vendor-swagger.py fetches and pins them; CI verifies the
        # hashes.
        swagger_js_url="/static/swagger/swagger-ui-bundle.js",
        swagger_css_url="/static/swagger/swagger-ui.css",
    )


@app.get("/healthz")
def healthz() -> dict[str, str]:
    # `service` lets observability scrapers (Prometheus relabel,
    # Datadog tags, Grafana log filters) tell shomer-api apart from
    # shomer-ssr's own /healthz without having to key on the
    # listening port — useful when both ride behind the same
    # ingress.
    return {"service": "shomer-api", "status": "ok", "version": __version__}


@app.get("/.well-known/openid-configuration")
def openid_configuration() -> dict[str, object]:
    base = OIDC_ISSUER
    return {
        "issuer": base,
        "authorization_endpoint": f"{base}/oauth2/authorize",
        "token_endpoint": f"{base}/oauth2/token",
        "jwks_uri": f"{base}/oauth2/jwks.json",
        "response_types_supported": ["code"],
        "grant_types_supported": ["authorization_code", "refresh_token"],
        "subject_types_supported": ["public"],
        "id_token_signing_alg_values_supported": ["RS256"],
        "code_challenge_methods_supported": ["S256"],
        # `scopes_supported` is REQUIRED by RFC 8414 (OAuth 2.0
        # authorization server metadata) and SHOULD be present per
        # OIDC discovery 1.0 §3 — advertise the minimal set we plan
        # to honour so codegen clients can wire `scope=` correctly
        # against the discovery doc instead of guessing.
        "scopes_supported": ["openid", "profile", "email"],
    }


def run() -> None:
    """Console-script entrypoint (``shomer-api``)."""
    import uvicorn

    # Container / systemd service must listen on all interfaces.
    uvicorn.run("shomer_api.app:app", host="0.0.0.0", port=8000)  # nosec B104
