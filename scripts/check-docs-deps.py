#!/usr/bin/env python3

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Assert that every component shown on the versions page cascades onto `docs`.

docs/versions.md renders `config.extra.versions.*` from zensical.toml, and
the site is republished only when the `docs` component itself releases —
`docs-build` is gated on `contains(changed, 'docs')`. So a component that
mirrors its version into zensical.toml without appearing in
`docs.depends_on` rewrites the number in the repository and leaves the
published page showing the old one.

That is not hypothetical: the two bootstrap components were added by hand
rather than through scripts/new-terraform-module.sh, which is what
maintains `docs.depends_on`, and they were the only two of forty-seven
missing. Nothing failed — the page was simply stale, which is the kind of
wrong that is never noticed.

Exits non-zero and names the offenders. Run by the `validate` CI job.
"""

from __future__ import annotations

import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    components = tomllib.loads((ROOT / "multicz.toml").read_text())["components"]

    mirrored = {
        name
        for name, spec in components.items()
        if any(b.get("file") == "zensical.toml" for b in spec.get("bump_files", []))
    }
    declared = set(components.get("docs", {}).get("depends_on") or [])

    # `docs` mirrors its own version and cannot depend on itself.
    missing = sorted(mirrored - declared - {"docs"})

    if missing:
        print("multicz.toml: these components publish a version to the docs page")
        print("but do not cascade onto `docs`, so the site will show a stale number:")
        for name in missing:
            print(f"  - {name}")
        print()
        print("Add them to [components.docs] depends_on.")
        return 1

    print(
        f"docs.depends_on covers all {len(mirrored) - 1} components shown on the versions page"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
