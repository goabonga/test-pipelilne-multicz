# Contributing

Thanks for your interest in Shomer.

## Setup

```bash
uv sync                          # installs all workspace members
uv run shomer-api                # FastAPI on :8000
uv run shomer-job             # background loop
uv run shomer health http://127.0.0.1:8000
```

## Layout

```
packages/
├── api/      shomer-api      FastAPI service + Helm chart + .deb
├── job/   shomer-job   polling job + Helm chart + .deb
└── cli/      shomer-cli      operator CLI (no chart, no deb)
```

Each package is an independent uv workspace member with its own
`pyproject.toml`. Versions, tags, changelogs and release commits are
managed per-package by [`multicz`](https://github.com/goabonga/multicz)
— see `multicz.toml`.

## Commits

Conventional Commits, scoped to the affected package(s):

```
feat(api): add token introspection endpoint
fix(job): handle SIGHUP without restarting
docs(cli): document `shomer health` flags
```

`multicz check` runs as the `commit-msg` hook to catch typos before
they land. Install once with:

```bash
echo '#!/bin/sh' > .git/hooks/commit-msg
echo 'exec uv run multicz check "$1"' >> .git/hooks/commit-msg
chmod +x .git/hooks/commit-msg
```

## Pull requests

- run `uv run pytest` and `uv run ruff check` before opening the PR
- preview the release plan locally: `uv run multicz plan`
- one logical change per commit; a PR can carry several commits

## Reporting security issues

See [SECURITY.md](SECURITY.md). Do **not** open a public issue for
authentication / token / session vulnerabilities.
