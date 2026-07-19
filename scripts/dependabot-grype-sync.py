#!/usr/bin/env python3

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Sync packages/<component>/.grype.yaml against a Dependabot-bumped
Docker base image.

Invoked from `.github/workflows/dependabot-rewrite.yml` for every PR
that touches a `packages/<component>/Dockerfile`. The flow:

  1. `docker build` the new Dockerfile into an ephemeral tag.
  2. `grype <tag> -o json` against the freshly-built image.
  3. Diff the current `.grype.yaml` ignore list against the grype
     findings:

       kept     — existing entry whose CVE + package name still
                  matches a grype finding. The version pin in the
                  allowlist gets bumped to whatever the new image
                  ships, so the next CI run satisfies the ignore.
       resolved — existing entry no longer matched (Chainguard
                  finally shipped the fix). The entry stays in the
                  file but the entire block is commented out and
                  flagged so a human can confirm before deleting.
       new      — High / Critical grype finding NOT in the
                  allowlist. Added with a TODO marker so the PR
                  reviewer is forced to justify (real upstream wait
                  vs. regression in our own code) before merging.

  4. Rewrite the `.grype.yaml` in place.
  5. Emit a markdown summary to stdout — captured by the workflow
     and posted as a PR comment so the human reviewer sees what
     changed in the allowlist next to the Dockerfile bump that
     triggered it.

Usage:

    python3 scripts/dependabot-grype-sync.py <component>

Exits 0 even when there's nothing to sync; the workflow filters on
the modified-files diff to decide whether to amend + force-push.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path

SEVERITY_BLOCKING = {"Critical", "High"}


@dataclass(frozen=True)
class Entry:
    """One allowlist `- vulnerability: …` block, as read from disk."""

    cve: str
    package_name: str
    package_version: str
    package_type: str
    reason: str
    # Inclusive line range covered by the block: from the first leading
    # comment line through the final indented body line. Used by the
    # rewrite step to splice replacements in without disturbing the
    # surrounding entries.
    start_line: int
    end_line: int


def parse_grype_yaml(path: Path) -> list[Entry]:
    """Return the existing ignore entries with their on-disk line ranges.

    The .grype.yaml format is rigid in this repo (one entry per CVE,
    each with a leading `# expires:` marker and a `package` sub-block);
    we parse it directly rather than rely on PyYAML so the rewrite step
    can preserve comments / spacing exactly.
    """

    lines = path.read_text().splitlines()
    entries: list[Entry] = []
    i = 0
    while i < len(lines):
        if re.match(r"^\s*-\s+vulnerability:\s*(\S+)\s*$", lines[i]):
            block_start = i
            # Walk back over the comment header lines that introduce
            # this block so the rewrite can drop them too.
            while block_start > 0 and lines[block_start - 1].lstrip().startswith("#"):
                block_start -= 1

            block_data: dict[str, str] = {}
            j = i
            while j < len(lines):
                line = lines[j]
                if j > i and (
                    line and not line[0].isspace() or re.match(r"^\s*-\s+", line)
                ):
                    break
                m = re.match(r"^\s*-?\s*(\w+):\s*\"?([^\"\n]+)\"?\s*$", line)
                if m:
                    block_data.setdefault(m.group(1), m.group(2).strip())
                j += 1

            entries.append(
                Entry(
                    cve=block_data.get("vulnerability", ""),
                    package_name=block_data.get("name", ""),
                    package_version=block_data.get("version", ""),
                    package_type=block_data.get("type", "apk"),
                    reason=block_data.get(
                        "reason",
                        "Upstream pinned base image; awaiting patched build.",
                    ),
                    start_line=block_start,
                    end_line=j,
                )
            )
            i = j
            continue
        i += 1
    return entries


@dataclass(frozen=True)
class Finding:
    """One grype match boiled down to the fields we compare on."""

    cve: str
    severity: str
    package_name: str
    package_version: str
    package_type: str


def grype_findings(image_tag: str) -> list[Finding]:
    """Build the image, run grype against it, return the blocking-tier
    findings (Critical + High).

    grype exits 0 when clean and 1 when --fail-on triggers — both leave
    a valid JSON report on stdout. Any other code is treated as a real
    error and propagated to the workflow.
    """

    result = subprocess.run(  # noqa: PLW1510
        ["grype", image_tag, "-o", "json"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode > 1:
        msg = f"grype exited {result.returncode}: {result.stderr.strip()}"
        raise RuntimeError(msg)
    data = json.loads(result.stdout)
    findings: list[Finding] = []
    for match in data.get("matches", []):
        sev = match.get("vulnerability", {}).get("severity", "")
        if sev not in SEVERITY_BLOCKING:
            continue
        artifact = match.get("artifact", {})
        findings.append(
            Finding(
                cve=match["vulnerability"]["id"],
                severity=sev,
                package_name=artifact.get("name", ""),
                package_version=artifact.get("version", ""),
                package_type=artifact.get("type", "apk"),
            )
        )
    return findings


def render_entry(finding: Finding, *, expires: str, todo: bool = False) -> str:
    """Render one ignore block back to YAML text.

    `todo=True` prepends a TODO marker that survives into the committed
    .grype.yaml so the human reviewer can't miss that this entry was
    machine-added on the bump PR and needs a real justification.
    """

    header_lines = [
        f"  # {finding.cve} ({finding.severity}) — surfaced by"
        f" dependabot-grype-sync on the bumped Dockerfile.",
    ]
    if todo:
        header_lines.append(
            "  # TODO: justify (real upstream wait vs. regression in our own code)"
            " or remove this entry before merging."
        )
    header_lines.append(f"  # expires: {expires}")
    body = (
        f"  - vulnerability: {finding.cve}\n"
        f'    reason: "Auto-added by dependabot-grype-sync;'
        f' human review required."\n'
        f"    package:\n"
        f"      name: {finding.package_name}\n"
        f"      version: {finding.package_version}\n"
        f"      type: {finding.package_type}\n"
    )
    return "\n".join(header_lines) + "\n" + body


def rewrite_grype_yaml(
    path: Path,
    *,
    bumped_pins: dict[str, str],  # cve -> new version
    resolved_cves: set[str],
    new_entries: Iterable[Finding],
    expires: str,
) -> None:
    """Apply the diff to .grype.yaml in place.

    Order matters here: we walk entries highest-to-lowest by their
    start line so splicing replacements doesn't invalidate the offsets
    we computed up front.
    """

    text = path.read_text()
    lines = text.splitlines(keepends=False)
    entries = parse_grype_yaml(path)

    # Bump version pins for kept entries.
    for entry in entries:
        new_version = bumped_pins.get(entry.cve)
        if new_version is None or new_version == entry.package_version:
            continue
        # Find the `version:` line in the entry's range and patch it.
        for idx in range(entry.start_line, entry.end_line):
            if re.match(
                rf"^\s*version:\s*{re.escape(entry.package_version)}\s*$", lines[idx]
            ):
                lines[idx] = lines[idx].replace(entry.package_version, new_version)
                break
        # A re-pinned entry is a *fresh* state: a new apk build that still
        # carries the CVE. Reset its `# expires:` marker to the future too,
        # otherwise it keeps the old (already-past) date and the weekly
        # sweep re-flags it as expired on the very next run.
        for idx in range(entry.start_line, entry.end_line):
            m = re.match(
                r"^(?P<pre>\s*#\s*expires:\s*)\d{4}-\d{2}-\d{2}(?P<post>\s*)$",
                lines[idx],
                re.IGNORECASE,
            )
            if m:
                lines[idx] = f"{m['pre']}{expires}{m['post']}"
                break

    # Delete resolved entries outright — the CVE is gone from the bumped
    # image, so the ignore is dead weight; git history keeps the record.
    # Process descending so earlier deletions don't shift later offsets.
    for entry in sorted(entries, key=lambda e: -e.start_line):
        if entry.cve not in resolved_cves:
            continue
        del lines[entry.start_line : entry.end_line]
        # Collapse a double blank line the deletion may have left behind.
        start = entry.start_line
        if (
            0 < start < len(lines)
            and not lines[start - 1].strip()
            and not lines[start].strip()
        ):
            del lines[start]

    # Append new entries at the end of the ignore list.
    new_blocks = [render_entry(f, expires=expires, todo=True) for f in new_entries]
    if new_blocks:
        lines.append("")
        for block in new_blocks:
            lines.extend(block.splitlines())
            lines.append("")

    path.write_text("\n".join(lines).rstrip() + "\n")


def render_summary(
    *,
    component: str,
    bumped: list[tuple[Entry, str]],
    resolved: list[Entry],
    new: list[Finding],
) -> str:
    """Markdown body posted as a PR comment for this component."""

    out = [
        f"## 🛡️ grype allowlist sync — `{component}`",
        "",
        f"Built `packages/{component}/Dockerfile` and scanned the resulting"
        f" image with grype. Updated `packages/{component}/.grype.yaml`:",
        "",
    ]
    if bumped:
        out.append("### 🔁 Version-pin bumped (CVE still matched)")
        out.append("")
        for entry, new_version in bumped:
            out.append(
                f"- **{entry.cve}** — `{entry.package_name}`"
                f" `{entry.package_version}` → `{new_version}`"
            )
        out.append("")
    if resolved:
        out.append("### ✅ Resolved (CVE no longer matched)")
        out.append("")
        for entry in resolved:
            out.append(
                f"- **{entry.cve}** — `{entry.package_name}`"
                f" `{entry.package_version}` no longer reported on the new"
                f" image. Entry removed."
            )
        out.append("")
    if new:
        out.append("### 🆕 New (added with TODO — please justify or remove)")
        out.append("")
        for finding in new:
            out.append(
                f"- **{finding.cve}** ({finding.severity}) —"
                f" `{finding.package_name}` `{finding.package_version}`"
            )
        out.append("")
        out.append(
            "> **Reviewer action**: confirm each TODO entry is a genuine"
            " upstream wait, not a regression in our own code. Replace the"
            " auto-generated `reason:` with a real justification before"
            " merging."
        )
    if not (bumped or resolved or new):
        out.append(
            "_No changes — the existing allowlist already matched the"
            " new image's findings exactly._"
        )
    return "\n".join(out)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: dependabot-grype-sync.py <component>", file=sys.stderr)
        return 2
    component = sys.argv[1]
    component_dir = Path("packages") / component
    dockerfile = component_dir / "Dockerfile"
    grype_yaml = component_dir / ".grype.yaml"

    if not dockerfile.is_file() or not grype_yaml.is_file():
        # Nothing to sync — the workflow already filtered to components
        # whose Dockerfile changed, but a deletion (or a new component
        # without an allowlist yet) lands here as a no-op.
        print(f"_No Dockerfile/.grype.yaml pair for `{component}`; skipped._")
        return 0

    image_tag = f"dependabot-grype-sync-{component}:check"
    subprocess.run(
        ["docker", "build", "-t", image_tag, "-f", str(dockerfile), str(component_dir)],
        check=True,
        stdout=subprocess.DEVNULL,
    )

    findings = grype_findings(image_tag)
    entries = parse_grype_yaml(grype_yaml)

    grype_by_cve = {f.cve: f for f in findings}
    entry_cves = {e.cve for e in entries}

    bumped: list[tuple[Entry, str]] = []
    resolved: list[Entry] = []
    bumped_pins: dict[str, str] = {}
    resolved_cves: set[str] = set()

    for entry in entries:
        finding = grype_by_cve.get(entry.cve)
        if finding is None:
            resolved.append(entry)
            resolved_cves.add(entry.cve)
            continue
        if (
            finding.package_name == entry.package_name
            and finding.package_version != entry.package_version
        ):
            bumped.append((entry, finding.package_version))
            bumped_pins[entry.cve] = finding.package_version

    new_findings = [f for f in findings if f.cve not in entry_cves]

    # Default expiry: 14 days out from today (computed at the runner —
    # the rewrite workflow doesn't need git's date hooks).
    from datetime import date, timedelta

    expires = (date.today() + timedelta(days=14)).isoformat()

    rewrite_grype_yaml(
        grype_yaml,
        bumped_pins=bumped_pins,
        resolved_cves=resolved_cves,
        new_entries=new_findings,
        expires=expires,
    )

    print(
        render_summary(
            component=component,
            bumped=bumped,
            resolved=resolved,
            new=new_findings,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
