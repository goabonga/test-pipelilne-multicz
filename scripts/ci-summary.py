#!/usr/bin/env python3

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Render a job summary from a tool's own output.

WHY THIS EXISTS

Every job in ci.yml ends with a summary that restates the command it ran:
"`grype --fail-on high` on the api SBOM". That is true and useless — it is
visible in the job name, and it says the same thing whether the scan found
nothing or forty things.

The information a reader wants is in the tool's output, which is either
thrown away or buried in a log they have to expand. These formatters read
the real artefact and put the part that matters on the run page.

WHAT EACH ONE IS FOR

The point is not decoration. Each formatter surfaces the fact that changes
a decision:

  grype           what was found, and what was SUPPRESSED — a scan that
                  passes because everything is allowlisted looks identical
                  to a clean one on the badge.
  checkov         the skips and their reasons. A green checkov run with
                  eight suppressions is a different thing from a green run
                  with none, and only one of them needs reviewing.
  terraform-test  how many assertions actually ran. A module whose tests
                  all skipped is green.
  sbom            what went into the image, by ecosystem.
  plan            per-unit create/change/destroy, so a destroy in a plan
                  nobody expanded is visible on the page.
  pytest          counts, and the names of what failed.

Usage:

    ci-summary.py <kind> <path> [--title TITLE]

Prints markdown on stdout. Unknown kinds and unreadable files degrade to a
one-line note rather than failing the job: a summary that breaks a green
build teaches people to remove summaries.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# Order matters: it is the order severities are printed in, worst first.
SEVERITIES = ["Critical", "High", "Medium", "Low", "Negligible", "Unknown"]


def _read_json(path: Path):
    return json.loads(path.read_text())


def _table(headers: list[str], rows: list[list[str]]) -> str:
    if not rows:
        return ""
    out = [
        "| " + " | ".join(headers) + " |",
        "|" + "|".join("---" for _ in headers) + "|",
    ]
    out += ["| " + " | ".join(str(c) for c in r) + " |" for r in rows]
    return "\n".join(out)


# ── formatters ──────────────────────────────────────────────────────────


def fmt_grype(path: Path) -> str:
    """Findings by severity, and — the point — what was suppressed.

    A scan that passes because every finding is allowlisted is
    indistinguishable from a clean one by the job badge alone. Both are
    green. Only one of them has an expiry date somebody should be watching.
    """
    data = _read_json(path)
    matches = data.get("matches", [])
    ignored = data.get("ignoredMatches", [])

    counts: dict[str, int] = {}
    for m in matches:
        sev = (m.get("vulnerability") or {}).get("severity", "Unknown")
        counts[sev] = counts.get(sev, 0) + 1

    lines = []
    if not matches and not ignored:
        lines.append("No known vulnerabilities.")
    else:
        rows = [[s, counts[s]] for s in SEVERITIES if counts.get(s)]
        if rows:
            lines.append(_table(["severity", "found"], rows))
        else:
            lines.append("Nothing found above the gate.")

    if ignored:
        lines.append("")
        lines.append(
            f"**{len(ignored)} suppressed by the allowlist.** A scan that "
            f"passes because of these looks the same on the badge as one "
            f"with nothing to suppress."
        )
        rows = []
        for m in ignored[:10]:
            v = m.get("vulnerability") or {}
            art = m.get("artifact") or {}
            rows.append(
                [
                    v.get("id", "?"),
                    v.get("severity", "?"),
                    f"{art.get('name', '?')} {art.get('version', '')}".strip(),
                ]
            )
        lines.append("")
        lines.append(_table(["cve", "severity", "package"], rows))
        if len(ignored) > 10:
            lines.append("")
            lines.append(f"…and {len(ignored) - 10} more.")

    return "\n".join(lines)


def fmt_checkov(path: Path) -> str:
    """Counts, and every skip with the reason its author wrote.

    Green with eight suppressions and green with none are different states,
    and the run page should not report them identically. The reasons are
    reproduced verbatim because a skip whose reason does not survive being
    read out loud is one worth questioning.
    """
    data = _read_json(path)
    # checkov emits a list when several frameworks ran.
    frames = data if isinstance(data, list) else [data]

    passed = failed = skipped = 0
    skips: list[list[str]] = []
    fails: list[list[str]] = []

    for frame in frames:
        results = frame.get("results") or {}
        passed += len(results.get("passed_checks") or [])
        for c in results.get("failed_checks") or []:
            failed += 1
            fails.append(
                [
                    c.get("check_id", "?"),
                    (c.get("resource") or "?").split(".")[-1],
                    c.get("check_name", "")[:70],
                ]
            )
        for c in results.get("skipped_checks") or []:
            skipped += 1
            # Nested under check_result, not at the top level — the
            # top-level key does not exist and reading it yields None for
            # every skip, which renders as "no reason given" for skips that
            # have perfectly good ones.
            #
            # Checkov captures only the text on the SAME LINE as the
            # `checkov:skip=` directive. A reason wrapped across several
            # comment lines is silently truncated here, so the first line
            # has to carry the point.
            reason = (
                (
                    ((c.get("check_result") or {}).get("suppress_comment"))
                    or c.get("suppress_comment")
                    or ""
                )
                .strip()
                .replace("\n", " ")
            )
            skips.append(
                [
                    c.get("check_id", "?"),
                    (c.get("resource") or "?").split(".")[-1],
                    reason[:160] or "**no reason given**",
                ]
            )

    lines = [f"**{passed} passed · {failed} failed · {skipped} skipped**"]

    if fails:
        lines += ["", "### Failed", "", _table(["check", "resource", "what"], fails)]

    if skips:
        lines += [
            "",
            "### Suppressed",
            "",
            _table(["check", "resource", "reason"], skips),
        ]
        if any(s[2].startswith("**no reason") for s in skips):
            lines += [
                "",
                (
                    "> A skip without a written reason tells the next reader "
                    "nothing they can act on."
                ),
            ]

    return "\n".join(lines)


def fmt_terraform_test(path: Path) -> str:
    """How many assertions ran, not merely whether the command exited zero.

    `terraform test` reports success when every run block was skipped, and
    a run block is skipped whenever an earlier one in the file failed. So a
    module can go green having asserted almost nothing.
    """
    text = path.read_text()

    # Terraform prints its own tally, and it is authoritative: counting
    # "... pass" lines also counts the per-FILE result alongside the per-run
    # ones, so a single-file module reads one higher than it ran.
    tally = re.search(
        r"(?:Success|Failure)!\s+(\d+) passed, (\d+) failed(?:, (\d+) skipped)?",
        text,
    )
    if tally:
        passed, failed = int(tally.group(1)), int(tally.group(2))
        skipped = int(tally.group(3) or 0)
    else:
        # No tally means terraform did not get as far as running anything —
        # a provider it could not load, a module it could not init. Say that
        # rather than reporting zeros, which read as "nothing to test".
        return (
            "_`terraform test` did not report a result — it failed before "
            "running any assertions. The usual cause is an uninitialised "
            "module rather than a broken test._"
        )

    if passed + failed + skipped == 0:
        # Terraform prints its tally even when it never ran anything, so
        # zeros are ambiguous: they mean "no assertions ran", which reads as
        # "nothing to test" and is usually "the module would not init".
        return (
            "_`terraform test` ran no assertions at all. It reports this the "
            "same way it reports a module with no tests, so check the log — "
            "the usual cause is a provider it could not load._"
        )

    lines = [f"**{passed} passed · {failed} failed · {skipped} skipped**"]

    names = re.findall(r'run "([^"]+)"\.\.\. (pass|fail|skip)', text)
    bad = [[n, s] for n, s in names if s != "pass"]
    if bad:
        lines += ["", _table(["run", "result"], bad)]

    if skipped and not failed:
        lines += [
            "",
            (
                "> Skipped runs are not neutral: a run block is skipped when an "
                "earlier one in the same file failed, so this file asserted less "
                "than it appears to."
            ),
        ]

    return "\n".join(lines)


def fmt_sbom(path: Path) -> str:
    """What actually went into the image, grouped by where it came from."""
    data = _read_json(path)
    packages = data.get("packages") or []

    by_origin: dict[str, int] = {}
    for p in packages:
        ext = p.get("externalRefs") or []
        origin = "other"
        for ref in ext:
            loc = ref.get("referenceLocator", "")
            if loc.startswith("pkg:"):
                origin = loc.split("/")[0].removeprefix("pkg:")
                break
        by_origin[origin] = by_origin.get(origin, 0) + 1

    rows = sorted(([k, v] for k, v in by_origin.items()), key=lambda r: -r[1])
    lines = [f"**{len(packages)} packages**"]
    if rows:
        lines += ["", _table(["ecosystem", "packages"], rows)]
    return "\n".join(lines)


def fmt_plan(path: Path) -> str:
    """Per-unit create/change/destroy from a terragrunt run.

    A destroy inside a plan nobody expanded is the thing worth putting on
    the page. The counts come from terraform's own summary line rather than
    from parsing the diff, so they cannot disagree with it.
    """
    text = path.read_text()
    text = re.sub(r"\x1b\[[0-9;]*[mK]", "", text)

    rows = []
    for unit, add, change, destroy in re.findall(
        r"\[([^\]]+)\][^\n]*Plan:\s*(\d+) to add, (\d+) to change, (\d+) to destroy",
        text,
    ):
        rows.append([unit, add, change, destroy])
    for unit in re.findall(r"\[([^\]]+)\][^\n]*No changes", text):
        rows.append([unit, "0", "0", "0"])

    if not rows:
        return "No plan output found."

    lines = [_table(["unit", "add", "change", "destroy"], rows)]

    destroys = sum(int(r[3]) for r in rows)
    if destroys:
        lines += [
            "",
            (
                f"> **{destroys} resources would be destroyed.** Read the "
                f"attached plan before approving."
            ),
        ]

    return "\n".join(lines)


def fmt_pytest(path: Path) -> str:
    """Counts from a junit report, and the names of what failed."""
    root = ET.parse(path).getroot()
    suites = root.findall(".//testsuite") or [root]

    tests = failures = errors = skipped = 0
    for s in suites:
        tests += int(s.get("tests", 0))
        failures += int(s.get("failures", 0))
        errors += int(s.get("errors", 0))
        skipped += int(s.get("skipped", 0))

    passed = tests - failures - errors - skipped
    lines = [
        (
            f"**{passed} passed · {failures} failed · {errors} errors · "
            f"{skipped} skipped**"
        )
    ]

    bad = []
    for case in root.iter("testcase"):
        if case.find("failure") is not None or case.find("error") is not None:
            bad.append([case.get("classname", ""), case.get("name", "")])
    if bad:
        lines += ["", _table(["suite", "test"], bad[:20])]

    return "\n".join(lines)


FORMATTERS = {
    "grype": fmt_grype,
    "checkov": fmt_checkov,
    "terraform-test": fmt_terraform_test,
    "sbom": fmt_sbom,
    "plan": fmt_plan,
    "pytest": fmt_pytest,
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("kind", choices=sorted(FORMATTERS))
    ap.add_argument("path", type=Path)
    ap.add_argument("--title", default="")
    args = ap.parse_args()

    if args.title:
        print(f"## {args.title}\n")

    # DEGRADE, NEVER FAIL. This runs in an `if: always()` step after the
    # work is done; a formatter that raises turns a passing job red for a
    # reporting problem, and the lesson people take from that is to stop
    # writing summaries.
    try:
        print(FORMATTERS[args.kind](args.path))
    except FileNotFoundError:
        print(f"_No `{args.kind}` output at `{args.path}` — nothing to summarise._")
    except Exception as exc:  # noqa: BLE001 - see the comment above
        print(f"_Could not summarise `{args.kind}` output: {exc}_")

    return 0


if __name__ == "__main__":
    sys.exit(main())
