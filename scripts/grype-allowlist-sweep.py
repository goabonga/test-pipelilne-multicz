#!/usr/bin/env python3

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Sweep packages/*/.grype.yaml allowlists; detect expired entries.

Each ignore entry MUST be preceded by a `# expires: YYYY-MM-DD` marker
comment line on its own. The script parses those markers, finds entries
whose expiration date is on or before today, and emits a JSON report on
stdout describing what to do with each:

  to_remove  expired AND --scan run + grype confirms the CVE is no
             longer matched against the latest published image (upstream
             fix landed; entry is mergeable garbage).

  to_review  expired AND CVE still matched, OR --scan disabled / image
             not pullable / grype not installed — i.e. the script can't
             prove the entry is safe to drop. The maintainer must
             re-justify with a fresh expiration date or remove the CVE
             through some other means.

The weekly grype-allowlist-sweep workflow consumes this report:
to_remove -> apply-removal mode rewrites the YAML files and opens an
auto PR; to_review -> opens or comments on a tracking issue.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections.abc import Iterator
from datetime import UTC, date, datetime
from pathlib import Path

# Only matches lines that are *purely* a marker comment (case-insensitive,
# tolerant of surrounding whitespace). Prose lines that happen to contain
# "expires:" are deliberately ignored to keep the parser predictable.
EXPIRES_RE = re.compile(r"^\s*#\s*expires:\s*(\d{4}-\d{2}-\d{2})\s*$", re.IGNORECASE)
VULN_RE = re.compile(r"^(\s*)-\s*vulnerability:\s*(\S+)\s*$")
GHCR_IMAGE_FMT = "ghcr.io/goabonga/shomer-{component}:{version}"
# `**` rather than `*`: packages/bdd/migrations/.grype.yaml sits two levels
# down and a single-star glob skipped it entirely. It is empty today, so
# nothing was actually missed — but the first ignore added there would have
# been a waiver that never expires and that no sweep ever reads, which is
# the exact failure this script exists to prevent.
ALLOWLIST_GLOB = "packages/**/.grype.yaml"


def parse(path: Path) -> Iterator[dict]:
    """Yield one entry dict per `- vulnerability:` block that has an
    immediately-preceding `# expires:` marker (possibly with descriptive
    comment lines between the marker and the entry).

    Each dict carries:
        vulnerability      CVE id parsed from the `- vulnerability:` line
        expires            datetime.date from the `# expires:` marker
        expired            bool, expires <= today
        start_line         0-indexed line where the comment block starts
                           (this is what apply-removal deletes from)
        end_line           exclusive line index where the entry's body ends
                           (next entry / blank line / de-indent)

    Entries lacking a marker are silently skipped — they're outside the
    sweep's contract.
    """
    lines = path.read_text().splitlines()
    today = datetime.now(UTC).date()

    pending_expires: date | None = None
    pending_block_start: int | None = None

    i = 0
    while i < len(lines):
        m_exp = EXPIRES_RE.match(lines[i])
        if m_exp:
            # Walk back over contiguous comment lines so apply-removal
            # also strips the descriptive comments belonging to this entry.
            block_start = i
            while block_start > 0 and lines[block_start - 1].lstrip().startswith("#"):
                block_start -= 1
            pending_expires = date.fromisoformat(m_exp.group(1))
            pending_block_start = block_start
            i += 1
            continue

        m_vuln = VULN_RE.match(lines[i])
        if m_vuln and pending_expires is not None:
            entry_indent = m_vuln.group(1)
            cve = m_vuln.group(2)
            # End of entry: next `<same-indent>- ` list item, blank line,
            # or de-indent back below entry indent.
            list_item_re = re.compile(rf"^{re.escape(entry_indent)}-\s")
            j = i + 1
            while j < len(lines):
                line_j = lines[j]
                if not line_j.strip():
                    break
                if list_item_re.match(line_j):
                    break
                if line_j and not line_j[0].isspace():
                    break
                # Body fields must be indented more than the entry itself.
                stripped = line_j.lstrip()
                indent_len = len(line_j) - len(stripped)
                if indent_len <= len(entry_indent):
                    break
                j += 1

            yield {
                "vulnerability": cve,
                "expires": pending_expires.isoformat(),
                "expired": pending_expires <= today,
                "start_line": pending_block_start,
                "end_line": j,
            }
            pending_expires = None
            pending_block_start = None
        i += 1


def _read_version(root: Path, component: str) -> str | None:
    """Return the published version of `component` from the VERSION file,
    or None if the file is missing, the line is missing, or the version
    is still the initial sentinel 0.0.0 (no image has been published yet)."""
    version_file = root / "VERSION"
    if not version_file.exists():
        return None
    for line in version_file.read_text().splitlines():
        if line.startswith(f"{component}="):
            v = line.split("=", 1)[1].strip()
            return v if v and v != "0.0.0" else None
    return None


def _grype_finds(image: str, cve: str) -> bool | None:
    """Run grype against `image` and return True if the report contains
    `cve`, False if not, or None when grype itself failed to run / parse —
    the caller MUST treat None conservatively (= still present)."""
    try:
        result = subprocess.run(
            ["grype", image, "-o", "json", "--quiet"],
            capture_output=True,
            text=True,
            timeout=600,
            check=False,
        )
    except FileNotFoundError:
        return None
    except subprocess.TimeoutExpired:
        return None

    # grype exits 0 when clean, 1 when --fail-on threshold met; both leave
    # a valid JSON report on stdout. Any other code is a real failure.
    if result.returncode > 1:
        return None
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    for match in data.get("matches", []):
        if match.get("vulnerability", {}).get("id") == cve:
            return True
    return False


def cmd_check(args: argparse.Namespace) -> int:
    report = {
        "generated": datetime.now(UTC).date().isoformat(),
        "to_remove": [],
        "to_review": [],
    }
    for path in sorted(args.root.glob(ALLOWLIST_GLOB)):
        component = path.parent.name
        image = None
        if args.scan:
            version = _read_version(args.root, component)
            if version:
                image = GHCR_IMAGE_FMT.format(component=component, version=version)

        for entry in parse(path):
            if not entry["expired"]:
                continue
            entry["file"] = str(path.relative_to(args.root))
            entry["component"] = component
            entry["image_scanned"] = image
            still = _grype_finds(image, entry["vulnerability"]) if image else None
            entry["cve_still_present"] = still
            # False (and only False) means grype proved the CVE is gone.
            # True or None both fall through to "needs review" — never
            # auto-drop an entry on incomplete information.
            if still is False:
                report["to_remove"].append(entry)
            else:
                report["to_review"].append(entry)

    json.dump(report, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


def cmd_apply_removal(args: argparse.Namespace) -> int:
    report = json.loads(args.report.read_text())
    by_file: dict[str, list[tuple[int, int]]] = {}
    for entry in report.get("to_remove", []):
        by_file.setdefault(entry["file"], []).append(
            (entry["start_line"], entry["end_line"])
        )

    for file_str, ranges in by_file.items():
        path = args.root / file_str
        lines = path.read_text().splitlines(keepends=True)
        # Sort high-to-low so each deletion doesn't shift indices for
        # subsequent ones in the same file.
        for start, end in sorted(ranges, reverse=True):
            del lines[start:end]
            # If the deletion left two consecutive blank lines, collapse
            # one of them to keep the file tidy.
            if (
                0 < start < len(lines)
                and not lines[start - 1].strip()
                and not lines[start].strip()
            ):
                del lines[start]
        # If we removed every entry under `ignore:`, force the explicit
        # empty-list form so grype's parser doesn't see a null mapping.
        text = "".join(lines)
        if re.search(r"^ignore:\s*$", text, flags=re.MULTILINE) and not re.search(
            r"^\s+-\s*vulnerability:", text, flags=re.MULTILINE
        ):
            text = re.sub(
                r"^ignore:\s*$", "ignore: []", text, count=1, flags=re.MULTILINE
            )
        path.write_text(text)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--root",
        type=Path,
        default=Path("."),
        help="Repo root (defaults to CWD)",
    )
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_check = sub.add_parser("check", help="Emit JSON report of expired entries")
    p_check.add_argument(
        "--scan",
        action="store_true",
        help="Re-run grype against the latest published image of each "
        "component to verify whether the CVE is still matched. Without "
        "--scan, every expired entry is conservatively reported as "
        "to_review.",
    )
    p_check.set_defaults(func=cmd_check)

    p_apply = sub.add_parser(
        "apply-removal",
        help="Rewrite .grype.yaml files in place, deleting the to_remove "
        "entries from a saved --check report.",
    )
    p_apply.add_argument("--report", type=Path, required=True)
    p_apply.set_defaults(func=cmd_apply_removal)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
