# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Shomer admin CLI surface.

Two subcommands sketch the operator workflow:

* ``shomer health <url>`` — probe a Shomer instance's ``/healthz``
  and print the JSON body (or exit non-zero on a non-2xx response).
* ``shomer version`` — print the installed CLI version.
"""

from __future__ import annotations

import httpx
import typer

from . import __version__

app = typer.Typer(
    add_completion=False,
    help="Operator CLI for Shomer authorization servers.",
)


@app.command()
def health(
    url: str = typer.Argument("http://127.0.0.1:8000", help="Shomer base URL."),
) -> None:
    """Probe a Shomer instance's ``/healthz`` and print the result."""
    response = httpx.get(f"{url.rstrip('/')}/healthz", timeout=5.0)
    response.raise_for_status()
    typer.echo(response.text)


@app.command()
def version() -> None:
    """Print the CLI version."""
    typer.echo(__version__)
