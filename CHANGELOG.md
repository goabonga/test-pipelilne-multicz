# Changelog

All notable changes across components, aggregated per release.
Per-component details live under `packages/<comp>/CHANGELOG.md`.

## 2026-06-19

### Releases

- **chart-job** patch — 1.0.3 → 1.0.4  _(cascade from job 1.1.0)_
- **docs** patch — 1.0.3 → 1.0.4  _(cascade from job 1.1.0)_
- **job** minor — 1.0.3 → 1.1.0

### Features

- **job**: run as a celery worker backed by redis (`9403e09`)

### Fixes

- **job**: satisfy mypy --strict on the celery worker (`2afbe4e`)

## 2026-06-18

### Releases

- **api** patch — 0.2.3 → 0.2.4  _(cascade from database 0.1.0)_
- **chart-api** patch — 1.0.6 → 1.0.7  _(cascade from api 0.2.4)_
- **chart-job** patch — 1.0.2 → 1.0.3  _(cascade from job 1.0.3)_
- **chart-migrations** minor — 0.0.0 → 0.1.0  _(cascade from migrations 0.1.0)_
- **database** minor — 0.0.0 → 0.1.0
- **docs** patch — 1.0.2 → 1.0.3  _(cascade from api 0.2.4)_
- **job** patch — 1.0.2 → 1.0.3  _(cascade from database 0.1.0)_
- **migrations** minor — 0.0.0 → 0.1.0  _(cascade from database 0.1.0)_

### Features

- **chart-migrations**: add shomer-migrations package (`dfa8e59`)
- **database**: add shomer-database package (`0a69c40`)
- **migrations**: add shomer-migrations package (`dfa8e59`)

### Fixes

- **chart-migrations**: add a baseline NetworkPolicy for the migration pod (`a45f2ad`)

## 2026-06-14

### Releases

- **docs** patch — 1.0.1 → 1.0.2
