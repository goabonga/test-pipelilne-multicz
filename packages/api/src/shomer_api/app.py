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

from fastapi import FastAPI

from . import __version__

app = FastAPI(title="Shomer", version=__version__)


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok", "version": __version__}


@app.get("/.well-known/openid-configuration")
def openid_configuration() -> dict[str, object]:
    base = "http://localhost:8000"
    return {
        "issuer": base,
        "authorization_endpoint": f"{base}/oauth2/authorize",
        "token_endpoint": f"{base}/oauth2/token",
        "jwks_uri": f"{base}/oauth2/jwks.json",
        "response_types_supported": ["code"],
        "grant_types_supported": ["authorization_code", "refresh_token"],
        "subject_types_supported": ["public"],
        "id_token_signing_alg_values_supported": ["RS256"],
    }


def run() -> None:
    """Console-script entrypoint (``shomer-api``)."""
    import uvicorn

    uvicorn.run("shomer_api.app:app", host="0.0.0.0", port=8000)
