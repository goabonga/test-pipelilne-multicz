---
icon: lucide/scroll
---

# Changelog

Each Shomer component has its own version stream and its own
`CHANGELOG.md`, managed by [`multicz`](https://github.com/goabonga/multicz).
Tags carry the per-component prefix (`api-vX.Y.Z`,
`chart-worker-vX.Y.Z`, …) so they don't collide.

## Per-component logs

| component       | distribution             | changelog                                                             |
|-----------------|--------------------------|-----------------------------------------------------------------------|
| `shomer-api`    | docker / helm / `.deb`   | [packages/api/CHANGELOG.md](https://github.com/goabonga/shomer/blob/main/packages/api/CHANGELOG.md)             |
| `shomer-worker` | docker / helm / `.deb`   | [packages/worker/CHANGELOG.md](https://github.com/goabonga/shomer/blob/main/packages/worker/CHANGELOG.md)       |
| `shomer-cli`    | wheel / sdist            | [packages/cli/CHANGELOG.md](https://github.com/goabonga/shomer/blob/main/packages/cli/CHANGELOG.md)             |
| `chart-api`     | helm OCI                 | [packages/api/chart/CHANGELOG.md](https://github.com/goabonga/shomer/blob/main/packages/api/chart/CHANGELOG.md) |
| `chart-worker`  | helm OCI                 | [packages/worker/chart/CHANGELOG.md](https://github.com/goabonga/shomer/blob/main/packages/worker/chart/CHANGELOG.md) |

## Debian stanzas

The `api` and `worker` components also keep a parallel
`debian/changelog` written by their `debian-changelog` writer — that
file is the canonical "Debian source view" of the same release stream:

- [packages/api/debian/changelog](https://github.com/goabonga/shomer/blob/main/packages/api/debian/changelog)
- [packages/worker/debian/changelog](https://github.com/goabonga/shomer/blob/main/packages/worker/debian/changelog)

## Aggregate version

The repo-root [`VERSION`](https://github.com/goabonga/shomer/blob/main/VERSION)
file mirrors every component's currently-released version, one line
per component. It exists primarily as a single watch path for the
docs-publish workflow, and as a quick "what's the current state" lookup:

```
api=X.Y.Z
worker=X.Y.Z
cli=X.Y.Z
chart-api=X.Y.Z
chart-worker=X.Y.Z
```

Bumping any component rewrites its line in `VERSION` (via the
`bump_files` regex declared in `multicz.toml`).

## How releases happen

```bash
multicz status        # what would bump
multicz plan          # detailed plan + reasons
multicz bump          # apply versions, mirrors, writers, post_bump
multicz graph         # cascade DAG (api -> chart-api etc.)
```

In CI, the [`release` workflow](https://github.com/goabonga/shomer/blob/main/.github/workflows/release.yml)
runs `multicz bump --commit --tag --push` after a green `ci`, then
builds and pushes the Docker images, Helm charts, and `.deb`
packages — see the [release pipeline summary](#) for the full graph.
