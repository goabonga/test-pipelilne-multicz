# Changelog

The shared Flux wiring — `apps/base/`, `clusters/`, `infrastructure/` —
everything both environments include but neither owns. Versions follow
[Semantic Versioning](https://semver.org), are derived from
[Conventional Commits](https://www.conventionalcommits.org) scoped to those
directories, and are tagged `gitops-v<version>`.

A library, released on every push to `main` that touches it — unlike
`gitops-staging` / `gitops-production`, which are deployed state and move
only when a promotion lands.

## [0.3.0] - 2026-08-08

### Features

- **gitops**: flux layout with pinned staging and production (`799dccf`)
- **gitops**: promotion workflows for staging and production (`745a6b6`)

## [0.2.0] - 2026-08-08

### Features

- **gitops**: flux layout with pinned staging and production (`799dccf`)
- **gitops**: promotion workflows for staging and production (`745a6b6`)

## [0.1.0] - 2026-08-08

### Features

- **gitops**: flux layout with pinned staging and production (`799dccf`)
- **gitops**: promotion workflows for staging and production (`745a6b6`)
