#!/usr/bin/env python3

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Vendor the Swagger UI assets so /docs loads nothing from a CDN.

WHY

FastAPI's `get_swagger_ui_html` points at cdn.jsdelivr.net by default.
That works, and it means every reader of the API documentation fetches a
1.5 MB script from a third party — which is a dependency the rest of this
repository would never accept silently. The images are signed, the charts
are verified at admission, the workloads reach the internet only through a
filtering proxy, and then the docs page loads executable code from
whatever the CDN returns today.

It also breaks in exactly the environment this infrastructure is built
for: a browser on a private network with no route out cannot reach
jsdelivr, so /docs renders as an unstyled page with no UI and no error
that says why.

WHAT IT PINS

An exact version, not the `@5` range the default URL uses. A floating
major means the file can change under a deployment that did not change,
and the whole point of vendoring is that it cannot.

Each file is recorded with its SHA-256 in swagger-lock.json. A re-run
verifies what it downloaded against that lock and refuses a mismatch:
without it, "vendored" means "a copy of whatever the CDN served the day
somebody ran this", which is the problem restated rather than solved.

Usage:

    scripts/vendor-swagger.py                 # install the pinned version
    scripts/vendor-swagger.py --update 5.32.13  # move the pin, rewrite the lock
    scripts/vendor-swagger.py --check         # verify, change nothing (CI)
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCK = ROOT / "scripts" / "swagger-lock.json"

CDN = "https://cdn.jsdelivr.net/npm/swagger-ui-dist@{version}/{name}"
FILES = ("swagger-ui.css", "swagger-ui-bundle.js")

# Both packages serve their own copy. Sharing one would mean an import path
# crossing package boundaries, and each wheel has to be installable on its
# own — a docs page that renders only when its sibling happens to be
# installed is worse than a slightly larger wheel.
TARGETS = {
    "api": ROOT / "packages" / "api" / "src" / "shomer_api" / "static" / "swagger",
    "ssr": ROOT / "packages" / "ssr" / "src" / "shomer_ssr" / "static" / "swagger",
}


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _fetch(version: str, name: str) -> bytes:
    url = CDN.format(version=version, name=name)
    print(f"  fetching {url}")
    try:
        with urllib.request.urlopen(url, timeout=60) as response:
            return response.read()
    except urllib.error.HTTPError as exc:
        raise SystemExit(
            f"error: {url} returned {exc.code}. If the version is wrong the "
            f"CDN answers 404 with an HTML body, so check the pin before "
            f"assuming the network."
        ) from None
    except urllib.error.URLError as exc:
        raise SystemExit(
            f"error: could not reach {url} ({exc.reason}). This script is the "
            f"one thing here that needs the internet — everything it produces "
            f"is committed so that nothing else does."
        ) from None


def _read_lock() -> dict:
    if not LOCK.is_file():
        return {}
    return json.loads(LOCK.read_text())


def cmd_check(lock: dict) -> int:
    """Verify what is on disk against the lock. Changes nothing."""
    if not lock:
        print("error: no swagger-lock.json — run without --check first")
        return 1

    problems = []
    for pkg, directory in TARGETS.items():
        for name in FILES:
            path = directory / name
            if not path.is_file():
                problems.append(f"{pkg}: {name} missing")
                continue
            actual = _sha256(path.read_bytes())
            expected = lock["files"][name]
            if actual != expected:
                problems.append(
                    f"{pkg}: {name} does not match the lock "
                    f"({actual[:12]}… vs {expected[:12]}…)"
                )

    if problems:
        print(f"Swagger assets disagree with swagger-lock.json (v{lock['version']}):\n")
        for p in problems:
            print(f"  - {p}")
        print(
            "\nEither the files were edited by hand — they are vendored, not "
            "ours to edit — or the lock was updated without re-running the "
            "script. `scripts/vendor-swagger.py` fixes both."
        )
        return 1

    print(f"swagger assets match the lock (v{lock['version']})")
    return 0


def cmd_install(version: str, lock: dict) -> int:
    """Download, verify against the lock when there is one, and write."""
    downloaded: dict[str, bytes] = {}
    digests: dict[str, str] = {}

    for name in FILES:
        data = _fetch(version, name)
        digest = _sha256(data)

        # A pin that is not verified is a version number with no teeth.
        if lock and lock.get("version") == version:
            expected = lock["files"].get(name)
            if expected and expected != digest:
                print(
                    f"error: {name} at v{version} hashes to {digest[:12]}… but "
                    f"the lock says {expected[:12]}…\n\n"
                    f"The same version served different bytes. That is either "
                    f"a republished package or something between here and the "
                    f"CDN, and neither is something to write into the "
                    f"repository without looking."
                )
                return 1

        downloaded[name] = data
        digests[name] = digest

    for directory in TARGETS.values():
        directory.mkdir(parents=True, exist_ok=True)
        for name, data in downloaded.items():
            (directory / name).write_bytes(data)
        print(f"  wrote {len(downloaded)} files into {directory.relative_to(ROOT)}")

    LOCK.write_text(
        json.dumps(
            {
                "_comment": (
                    "Pins the vendored Swagger UI. Regenerate with "
                    "scripts/vendor-swagger.py --update <version>; verify with "
                    "--check, which CI runs."
                ),
                "version": version,
                "source": CDN.format(version=version, name="<file>"),
                "files": digests,
            },
            indent=2,
        )
        + "\n"
    )
    print(f"  pinned swagger-ui-dist v{version} in {LOCK.relative_to(ROOT)}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--update",
        metavar="VERSION",
        help="move the pin to an exact version, e.g. 5.32.13",
    )
    ap.add_argument(
        "--check",
        action="store_true",
        help="verify the vendored files against the lock, change nothing",
    )
    args = ap.parse_args()

    lock = _read_lock()

    if args.check:
        return cmd_check(lock)

    version = args.update or lock.get("version")
    if not version:
        print(
            "error: no version. There is no default on purpose — the CDN's "
            "`@5` resolves to whatever is newest, which is the thing this "
            "script exists to stop.\n\n"
            "Pass --update <version>; today that is 5.32.13."
        )
        return 1

    return cmd_install(version, lock)


if __name__ == "__main__":
    sys.exit(main())
