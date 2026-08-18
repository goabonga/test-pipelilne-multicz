# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

import pytest
from fastapi.testclient import TestClient
from shomer_api import __version__
from shomer_api.app import app

client = TestClient(app)


def test_healthz_returns_status_and_version() -> None:
    response = client.get("/healthz")
    assert response.status_code == 200
    body = response.json()
    assert body == {"service": "shomer-api", "status": "ok", "version": __version__}


def test_openid_configuration_lists_required_metadata() -> None:
    response = client.get("/.well-known/openid-configuration")
    assert response.status_code == 200
    body = response.json()
    for key in (
        "issuer",
        "authorization_endpoint",
        "token_endpoint",
        "jwks_uri",
        "response_types_supported",
        "grant_types_supported",
    ):
        assert key in body, key
    assert "code" in body["response_types_supported"]
    assert "authorization_code" in body["grant_types_supported"]
    assert "RS256" in body["id_token_signing_alg_values_supported"]


def test_run_invokes_uvicorn(monkeypatch: pytest.MonkeyPatch) -> None:
    from shomer_api import app as appmod

    calls: list[dict[str, object]] = []
    monkeypatch.setattr(
        "uvicorn.run",
        lambda *args, **kwargs: calls.append({"args": args, "kwargs": kwargs}),
    )
    appmod.run()
    assert calls
    assert calls[0]["args"][0] == "shomer_api.app:app"  # type: ignore[index]
    assert calls[0]["kwargs"]["port"] == 8000  # type: ignore[index]


def test_favicon_is_served_as_an_image() -> None:
    # The api serves no HTML of its own, so before this route a browser's
    # automatic /favicon.ico request 404'd on every tab with the docs open.
    response = client.get("/favicon.ico")

    assert response.status_code == 200
    assert response.headers["content-type"] == "image/x-icon"
    # Real ICO header, so an error page cannot pass this.
    assert response.content[:4] == b"\x00\x00\x01\x00"


def test_docs_serve_swagger_with_the_shomer_favicon() -> None:
    # FastAPI's built-in /docs is disabled so this route can pass
    # swagger_favicon_url, which is the only lever the library offers for
    # the icon — hence owning the route rather than configuring it.
    response = client.get("/docs")

    assert response.status_code == 200
    assert "swagger-ui" in response.text
    assert "/favicon.ico" in response.text


def test_docs_load_no_third_party_assets() -> None:
    # THE assertion. FastAPI's default points Swagger UI at jsdelivr, so
    # every reader of this page fetches 1.5 MB of executable code from a
    # third party — and on the private network this deploys into, the
    # fetch simply fails and the page renders unstyled with nothing to say
    # why.
    response = client.get("/docs")

    assert "jsdelivr" not in response.text
    assert "/static/swagger/swagger-ui-bundle.js" in response.text
    assert "/static/swagger/swagger-ui.css" in response.text


def test_the_vendored_assets_are_actually_served() -> None:
    # The page referencing a local path proves nothing if the path 404s.
    for path in (
        "/static/swagger/swagger-ui-bundle.js",
        "/static/swagger/swagger-ui.css",
    ):
        response = client.get(path)
        assert response.status_code == 200, path
        # A 404 body would also be "content"; size is what distinguishes
        # the real bundle from an error page.
        assert len(response.content) > 10_000, path
