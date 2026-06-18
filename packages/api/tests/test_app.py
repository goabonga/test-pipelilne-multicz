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
