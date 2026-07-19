#!/usr/bin/env python3

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Local grype allowlist refresher — one branch + PR per component.

For each component it:

  1. (optional) re-resolves the Chainguard base-image *digests* pinned in
     `packages/<c>/Dockerfile` to whatever the `latest` / `latest-dev`
     tags point at now. Chainguard rebuilds the same tag with patched
     apks, so re-pinning the digest is how upstream fixes actually land —
     no version-tag guessing.
  2. builds that Dockerfile and scans the image with grype.
  3. reconciles `packages/<c>/.grype.yaml`, reusing the exact logic the
     Dependabot rewrite already uses (drop resolved / re-pin kept / add
     new High+Critical with a fresh `# expires:`).
  4. opens a branch `grype-refresh/<c>`, commits, and files a PR.
  5. files (or reuses) a tracking issue and cross-links the PRs to it.

This is the local counterpart to the CI `grype-allowlist-sweep`: that
workflow can only scan the *published* image and, when it can't (private
pull, image predates the CVE), bails to a review issue with
`cve_still_present: null` (see issue #59). Running against the freshly
*built* Dockerfile sidesteps that and produces an actionable PR.

Usage:
    scripts/grype-refresh.py --component ssr
    scripts/grype-refresh.py --all --issue 59
    scripts/grype-refresh.py --all --dry-run          # read-only preview
    scripts/grype-refresh.py --component api --no-bump-base --no-pr

Requires: docker, grype, git, gh — run from the repo root.
"""

from __future__ import annotations

import argparse
import importlib.util
import re
import subprocess
import sys
from datetime import date, timedelta
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
COMPONENTS = ["api", "job", "ssr"]
BASE_IMAGE = "cgr.dev/chainguard/python"
# Match `FROM cgr.dev/chainguard/python:<tag>@sha256:<digest>` so we can
# swap just the digest while leaving the human-readable tag in place.
FROM_RE = re.compile(
    r"(FROM\s+"
    + re.escape(BASE_IMAGE)
    + r":(?P<tag>[\w.-]+)@)(?P<digest>sha256:[0-9a-f]{64})"
)


def _load_sync_module():
    """Import the hyphenated sibling `dependabot-grype-sync.py` by path so
    we can reuse its parse/scan/rewrite/summary helpers verbatim."""
    path = HERE / "dependabot-grype-sync.py"
    spec = importlib.util.spec_from_file_location("dependabot_grype_sync", path)
    if spec is None or spec.loader is None:  # pragma: no cover - import guard
        msg = f"cannot load {path}"
        raise RuntimeError(msg)
    mod = importlib.util.module_from_spec(spec)
    # Register before exec: @dataclass in the target resolves its own
    # module via sys.modules, which is None unless we insert it first.
    sys.modules[spec.name] = mod
    spec.loader.exec_module(mod)
    return mod


sync = _load_sync_module()


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    """Thin `subprocess.run` wrapper that echoes the command for auditability."""
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, check=True, text=True, **kw)  # noqa: PLW1510


def latest_digest(tag: str) -> str:
    """Return the current index digest of `BASE_IMAGE:tag` without pulling
    the image (buildx imagetools reads the registry manifest only).

    `--format '{{.Manifest.Digest}}'` is unreliable across buildx versions
    (some ignore it and print the default report), so parse the first
    top-level `Digest:` line instead — that's the multi-arch index digest
    the Dockerfile pins."""
    out = subprocess.run(
        ["docker", "buildx", "imagetools", "inspect", f"{BASE_IMAGE}:{tag}"],
        check=True,
        text=True,
        capture_output=True,
    ).stdout
    for line in out.splitlines():
        stripped = line.strip()
        if stripped.startswith("Digest:"):
            digest = stripped.split(":", 1)[1].strip()
            if digest.startswith("sha256:"):
                return digest
    msg = f"no index digest in imagetools output for {BASE_IMAGE}:{tag}"
    raise RuntimeError(msg)


def bump_base_digests(dockerfile: Path) -> list[tuple[str, str, str]]:
    """Re-pin every `FROM BASE_IMAGE:tag@sha256:…` in `dockerfile` to the
    tag's current digest. Returns [(tag, old_digest, new_digest), …] for
    the ones that actually moved."""
    text = dockerfile.read_text()
    moved: list[tuple[str, str, str]] = []
    resolved: dict[str, str] = {}

    def repl(m: re.Match) -> str:
        tag, old = m["tag"], m["digest"]
        new = resolved.get(tag) or resolved.setdefault(tag, latest_digest(tag))
        if new != old:
            moved.append((tag, old, new))
        return f"{m.group(1)}{new}"

    new_text = FROM_RE.sub(repl, text)
    if new_text != text:
        dockerfile.write_text(new_text)
    return moved


def reconcile(component: str, image_tag: str) -> tuple[str, bool]:
    """Diff the built image's grype findings against the component's
    allowlist and rewrite it. Returns (markdown_summary, changed?)."""
    grype_yaml = REPO / "packages" / component / ".grype.yaml"
    findings = sync.grype_findings(image_tag)
    entries = sync.parse_grype_yaml(grype_yaml)

    by_cve = {f.cve: f for f in findings}
    entry_cves = {e.cve for e in entries}

    bumped, resolved = [], []
    bumped_pins: dict[str, str] = {}
    resolved_cves: set[str] = set()
    for entry in entries:
        finding = by_cve.get(entry.cve)
        if finding is None:
            resolved.append(entry)
            resolved_cves.add(entry.cve)
        elif (
            finding.package_name == entry.package_name
            and finding.package_version != entry.package_version
        ):
            bumped.append((entry, finding.package_version))
            bumped_pins[entry.cve] = finding.package_version

    new = [f for f in findings if f.cve not in entry_cves]
    expires = (date.today() + timedelta(days=14)).isoformat()

    before = grype_yaml.read_text()
    sync.rewrite_grype_yaml(
        grype_yaml,
        bumped_pins=bumped_pins,
        resolved_cves=resolved_cves,
        new_entries=new,
        expires=expires,
    )
    changed = grype_yaml.read_text() != before
    summary = sync.render_summary(
        component=component, bumped=bumped, resolved=resolved, new=new
    )
    return summary, changed


def process(component: str, *, bump_base: bool) -> dict | None:
    """Run the full refresh for one component. Returns a result dict when
    something changed (so the caller can open a PR), else None."""
    cdir = REPO / "packages" / component
    dockerfile = cdir / "Dockerfile"
    grype_yaml = cdir / ".grype.yaml"
    if not dockerfile.is_file() or not grype_yaml.is_file():
        print(f"[{component}] no Dockerfile/.grype.yaml — skipped")
        return None

    print(f"\n=== {component} ===")
    base_moves: list[tuple[str, str, str]] = []
    if bump_base:
        base_moves = bump_base_digests(dockerfile)
        for tag, old, new in base_moves:
            print(f"[{component}] base :{tag}  {old[:19]}… -> {new[:19]}…")
        if not base_moves:
            print(f"[{component}] base image already at latest digest")

    image_tag = f"grype-refresh-{component}:check"
    run(
        ["docker", "build", "-t", image_tag, "-f", str(dockerfile), str(cdir)],
        stdout=subprocess.DEVNULL,
    )

    summary, grype_changed = reconcile(component, image_tag)
    print(summary)

    changed_files = [
        str(p.relative_to(REPO)) for p in (dockerfile, grype_yaml) if _dirty(p)
    ]
    if not changed_files:
        print(f"[{component}] nothing to change — allowlist already in sync")
        return None

    return {
        "component": component,
        "files": changed_files,
        "summary": summary,
        "base_moves": base_moves,
        "grype_changed": grype_changed,
    }


def _dirty(path: Path) -> bool:
    """True if `path` has uncommitted changes in git."""
    rel = str(path.relative_to(REPO))
    return bool(
        subprocess.run(
            ["git", "-C", str(REPO), "status", "--porcelain", "--", rel],
            check=True,
            text=True,
            capture_output=True,
        ).stdout.strip()
    )


def open_pr(result: dict, *, issue: int | None, dry_run: bool) -> str | None:
    """Branch, commit the component's changes, push, and open a PR.
    Returns the PR URL (or None in dry-run)."""
    comp = result["component"]
    branch = f"grype-refresh/{comp}"
    base_note = "".join(
        f"\n- base `:{t}` re-pinned `{o[:19]}…` → `{n[:19]}…`"
        for t, o, n in result["base_moves"]
    )
    body = (
        f"Automated grype refresh for `{comp}` "
        f"(scripts/grype-refresh.py).{base_note}\n\n{result['summary']}"
    )
    if issue:
        body += f"\n\nRefs #{issue}"
    subject = f"fix({comp}): refresh grype allowlist against the current base image"

    if dry_run:
        print(f"[{comp}] DRY-RUN — would open PR on branch {branch}")
        print(f"[{comp}] files: {', '.join(result['files'])}")
        return None

    run(["git", "-C", str(REPO), "checkout", "-B", branch])
    run(["git", "-C", str(REPO), "add", *result["files"]])
    run(["git", "-C", str(REPO), "commit", "-m", subject, "-m", result["summary"]])
    run(["git", "-C", str(REPO), "push", "--force-with-lease", "-u", "origin", branch])
    out = run(
        [
            "gh",
            "pr",
            "create",
            "--head",
            branch,
            "--title",
            subject,
            "--body",
            body,
            "--label",
            "dependencies,ci",
        ],
        capture_output=True,
    ).stdout.strip()
    run(["git", "-C", str(REPO), "checkout", "-"])
    print(f"[{comp}] PR: {out}")
    return out


def ensure_issue(results: list[dict], issue: int | None, dry_run: bool) -> int | None:
    """Create a tracking issue (or reuse `issue`) and list the components
    refreshed. Returns the issue number."""
    if not results:
        return issue
    title = "grype allowlist refresh"
    lines = ["Automated `grype-refresh` run — one PR per component:", ""]
    lines += [
        f"- `{r['component']}` — {len(r['files'])} file(s) updated" for r in results
    ]
    body = "\n".join(lines)

    if dry_run:
        tgt = f"#{issue}" if issue else "a new issue"
        print(f"\n[issue] DRY-RUN — would update {tgt}:\n{body}")
        return issue

    if issue:
        run(["gh", "issue", "comment", str(issue), "--body", body])
        return issue
    out = run(
        [
            "gh",
            "issue",
            "create",
            "--title",
            title,
            "--body",
            body,
            "--label",
            "grype-allowlist-expired,ci",
        ],
        capture_output=True,
    ).stdout.strip()
    print(f"[issue] {out}")
    m = re.search(r"/issues/(\d+)", out)
    return int(m.group(1)) if m else None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--component", choices=COMPONENTS, help="refresh a single component")
    g.add_argument("--all", action="store_true", help="refresh api, job and ssr")
    ap.add_argument(
        "--no-bump-base",
        dest="bump_base",
        action="store_false",
        help="skip re-pinning the Chainguard base-image digest (rebuild only)",
    )
    ap.add_argument(
        "--no-pr",
        dest="open_pr",
        action="store_false",
        help="reconcile into the working tree only — no branch/commit/push/PR",
    )
    ap.add_argument(
        "--issue", type=int, help="existing tracking issue to link (e.g. 59)"
    )
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="build + scan + show the diff, but write nothing to git/gh",
    )
    args = ap.parse_args()

    targets = COMPONENTS if args.all else [args.component]
    results: list[dict] = []
    # Process one component fully before starting the next: a real
    # open_pr() commits that component's files onto its own branch and
    # switches back, leaving the tree clean — so the next component never
    # builds on top of another's uncommitted changes.
    for comp in targets:
        res = process(comp, bump_base=args.bump_base)
        if not res:
            continue
        results.append(res)
        if args.open_pr and not args.dry_run:
            open_pr(res, issue=args.issue, dry_run=False)
        elif args.dry_run:
            open_pr(res, issue=args.issue, dry_run=True)
            # dry-run didn't commit; restore this component's files now so
            # the next build starts from a clean tree.
            run(["git", "-C", str(REPO), "checkout", "--", *res["files"]])

    if not results:
        print("\nNothing to refresh — every component's allowlist is already in sync.")
        return 0

    if not args.open_pr and not args.dry_run:
        print("\n--no-pr: left changes in the working tree, no branch/PR created.")
    elif args.open_pr:
        ensure_issue(results, args.issue, args.dry_run)

    if args.dry_run:
        print("\n[dry-run] no branch, PR or issue created; working tree clean.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
