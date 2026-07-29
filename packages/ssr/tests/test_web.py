# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

from pathlib import Path

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from shomer_ssr import __version__
from shomer_ssr.app import DevAwareStaticFiles, app

client = TestClient(app)


def test_healthz_returns_status_and_version() -> None:
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "version": __version__}


def test_root_serves_the_spa_shell() -> None:
    response = client.get("/")
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/html")
    body = response.text
    assert 'id="root"' in body  # React mount point
    assert "shomer-ssr" in body
    assert __version__ in body  # rendered in the footer


def test_client_routes_serve_the_same_shell() -> None:
    """Deep links / refreshes on any client route return the shell so
    React Router can take over (SPA serving)."""
    for path in ("/login", "/some/deep/link"):
        response = client.get(path)
        assert response.status_code == 200
        assert response.headers["content-type"].startswith("text/html")
        assert 'id="root"' in response.text


def test_login_post_returns_ok_json() -> None:
    """The stub handler always succeeds with a 200 JSON body; the SPA
    navigates home client-side. Will evolve into a real cookie-session
    flow against shomer-api."""
    response = client.post(
        "/login",
        data={"username": "alice", "password": "wonderland"},
    )
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_run_invokes_uvicorn(monkeypatch: pytest.MonkeyPatch) -> None:
    from shomer_ssr import app as appmod

    calls: list[dict[str, object]] = []
    monkeypatch.setattr(
        "uvicorn.run",
        lambda *args, **kwargs: calls.append({"args": args, "kwargs": kwargs}),
    )
    appmod.run()
    assert calls
    assert calls[0]["args"][0] == "shomer_ssr.app:app"  # type: ignore[index]
    assert calls[0]["kwargs"]["port"] == 8080  # type: ignore[index]


def test_static_advertises_sourcemap_header(tmp_path: Path) -> None:
    (tmp_path / "main.js").write_text("console.log(1)\n")
    (tmp_path / "main.js.map").write_text("{}\n")
    (tmp_path / "plain.js").write_text("x\n")  # no sibling .map

    local = FastAPI()
    local.mount("/static", DevAwareStaticFiles(directory=str(tmp_path)), name="static")
    local_client = TestClient(local)

    mapped = local_client.get("/static/main.js")
    assert mapped.status_code == 200
    assert mapped.headers["SourceMap"] == "/static/main.js.map"

    unmapped = local_client.get("/static/plain.js")
    assert unmapped.status_code == 200
    assert "SourceMap" not in unmapped.headers
