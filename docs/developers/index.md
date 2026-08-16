---
icon: lucide/code
---

# For developers

Working in the repository: what is where, how to run it, and what the
pipeline will ask of a change before it lands.

## The workspace

A [uv workspace](https://docs.astral.sh/uv/concepts/projects/workspaces/)
of independently-versioned packages, plus a TypeScript half.

| package | role | distribution |
|---|---|---|
| `shomer-api` | FastAPI authorization server | image, chart, `.deb` |
| `shomer-job` | background jobs | image, chart, `.deb` |
| `shomer-ssr` | Jinja login / account UI | image, chart, `.deb` |
| `shomer-migrations` | Alembic revisions and runner | image, chart, `.deb` |
| `shomer-database` | SQLAlchemy models and connector | wheel |
| `shomer-cli` | operator CLI | wheel, `.deb` |
| `shomer-web` | React islands and CSS for `ssr` | built into `ssr` |
| `@shomer/lib` | shared TypeScript types and validation | used by `web`, `app` |
| `@shomer/app` | React Native app | store artifacts |

## Getting it running

```bash
make install                # sync the workspace, every package and dev group
uv run shomer-api &         # FastAPI on :8000
uv run shomer health http://127.0.0.1:8000
```

`make help` lists the rest. The targets CI runs are the same ones you run
locally — there is no separate CI-only path, so a green local run means
something.

## Committing

Conventional commits, enforced. `feat`, `fix`, `docs`, `style`, `refactor`,
`perf`, `test`, `build`, `ci`, `chore`, `revert`.

The type is not decoration: it decides the version bump, which decides
whether an image is built, a chart released and a deployment pinned. A
`chore` that should have been a `fix` is a fix nobody receives.

One commit is one logical change. Refactoring, formatting and behaviour go
in separate commits — the tree is meant to read as the sequence of
operations that were actually performed.

## Versioning, and why a change to one package moves another

Releases are managed by [`multicz`](https://github.com/goabonga/multicz).
Each package has its own tag, its own `CHANGELOG.md`, its own
`debian/changelog` stanza.

```bash
multicz status     # what would bump
multicz plan       # the plan, with reasons
multicz graph      # the cascade
```

The cascade is the part worth understanding. `database` is used by `api`,
so a change to `database` bumps `api`, which bumps `chart-api`, which is
what a deployment pins. Nothing about that is implicit — `multicz.toml`
declares every edge, and `multicz graph` draws it.

## What CI will ask

Per package, roughly: lint, tests, a container build, an SBOM, a
vulnerability scan, and for the ones that ship a `.deb`, an install test in
a clean container.

Two of those catch things a local run will not:

- **The `.deb` install test** boots the package in a container and asserts
  the installed version is the one the build was told to produce. It is how
  a packaging mistake surfaces as a failure rather than as a support
  ticket.
- **The chart policy test** stands up Kyverno in a throwaway cluster and
  proves the chart's image-verification policy actually rejects an unsigned
  image — then admits it once the policy is switched off. A policy that
  admits everything passes every test that only checks it is installed.

If a gate fails for a reason you believe is not yours to fix, the answer is
an exception with a written reason and, where the tool supports it, an
expiry: [creating an exception](../devsecops/exceptions.md).

## Adding a Terraform module

```bash
make infra-new-module NAME=network-thing-gcp
```

It scaffolds the module, registers it in `multicz.toml`, adds it to
`VERSION`, inserts its row in the docs table, generates its four CI jobs
and wires it into the units that depend on it. Doing any of that by hand
is how the two bootstrap components ended up missing from the docs
dependency list for weeks without anything failing.
