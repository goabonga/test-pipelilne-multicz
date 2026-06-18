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


def test_home_renders_html_with_login_link() -> None:
    response = client.get("/")
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/html")
    body = response.text
    assert "Shomer" in body
    assert 'href="/login"' in body
    assert __version__ in body  # rendered in the footer


def test_login_form_renders_username_and_password_fields() -> None:
    response = client.get("/login")
    assert response.status_code == 200
    body = response.text
    assert 'name="username"' in body
    assert 'name="password"' in body
    assert 'method="post"' in body


def test_login_post_redirects_to_home() -> None:
    """The stub handler always succeeds and 303-redirects to /. Will
    evolve into a real cookie-session flow against shomer-api."""
    response = client.post(
        "/login",
        data={"username": "alice", "password": "wonderland"},
        follow_redirects=False,
    )
    assert response.status_code == 303
    assert response.headers["location"] == "/"


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
