# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

from fastapi.testclient import TestClient

from shomer_web import __version__
from shomer_web.app import app

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
