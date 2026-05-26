## Description

<!-- Describe what this PR does and why. -->

## Type

<!-- Check the one that applies: -->

- [ ] `feat` - New feature
- [ ] `fix` - Bug fix
- [ ] `docs` - Documentation
- [ ] `refactor` - Code refactoring
- [ ] `test` - Adding or updating tests
- [ ] `chore` - Maintenance
- [ ] `ci` - CI / release pipeline

## Affected components

<!-- Tick every component touched (matches multicz.toml scopes): -->

- [ ] `api` (`packages/api`)
- [ ] `worker` (`packages/worker`)
- [ ] `web` (`packages/web`)
- [ ] `web-frontend` (`packages/web-frontend`)
- [ ] `cli` (`packages/cli`)
- [ ] `chart-api` / `chart-worker` / `chart-web`
- [ ] `docs`

## Changes

<!-- List the main changes introduced by this PR: -->

-

## Related issues

<!-- Link related issues: Closes #123, Fixes #456 -->

## Checklist

- [ ] Commits follow [Conventional Commits](https://www.conventionalcommits.org/) and are scoped to the affected component
- [ ] Branch is up to date with `main`
- [ ] `uv sync` succeeds
- [ ] `uv run ruff check` and `uv run ruff format --check` are clean
- [ ] `uv run pytest` passes
- [ ] `uv run multicz validate --strict` passes
- [ ] `uv run multicz plan` shows the expected release plan
- [ ] SPDX license headers are present (`python scripts/add_license_header.py --path . --types py,toml --check`)
- [ ] No `Co-Authored-By` trailer in commit messages
