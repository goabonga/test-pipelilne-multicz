# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

import httpx
import pytest
from typer.testing import CliRunner

from shomer_cli import __version__, main


def _ok_response(url: str, body: str = '{"status":"ok"}') -> httpx.Response:
    """Build a Response with the matching Request attached so
    ``response.raise_for_status()`` doesn't trip on a missing request."""
    return httpx.Response(200, request=httpx.Request("GET", url), text=body)


def test_version_command_prints_version() -> None:
    result = CliRunner().invoke(main.app, ["version"])
    assert result.exit_code == 0
    assert result.output.strip() == __version__


def test_health_command_targets_healthz_endpoint(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """``shomer health <base>`` must hit ``<base>/healthz`` and echo the
    raw response body."""
    captured: dict[str, object] = {}

    def fake_get(url: str, timeout: float) -> httpx.Response:
        captured["url"] = url
        captured["timeout"] = timeout
        return _ok_response(url, '{"status":"ok","version":"0.0.0"}')

    monkeypatch.setattr(main.httpx, "get", fake_get)

    result = CliRunner().invoke(main.app, ["health", "http://example.test/"])
    assert result.exit_code == 0
    assert captured["url"] == "http://example.test/healthz"
    assert "ok" in result.output


def test_health_command_strips_trailing_slashes(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The base URL is rstripped before joining ``/healthz`` so we don't
    end up requesting ``//healthz``."""
    captured: dict[str, str] = {}

    def fake_get(url: str, timeout: float) -> httpx.Response:
        captured["url"] = url
        return _ok_response(url)

    monkeypatch.setattr(main.httpx, "get", fake_get)

    result = CliRunner().invoke(main.app, ["health", "http://example.test///"])
    assert result.exit_code == 0
    assert captured["url"] == "http://example.test/healthz"
