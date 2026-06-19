# Changelog

All notable changes to this component are documented here.

## [1.1.0] - 2026-06-19

### Features

- **job**: run as a celery worker backed by redis (`9403e09`)

### Fixes

- **job**: satisfy mypy --strict on the celery worker (`2afbe4e`)

## [1.0.3] - 2026-06-18

### Dependencies

- Track `database` `0.1.0`

## [1.0.2] - 2026-06-13

### Fixes

- **job**: log the iteration index from tick() (`0400c5e`)

## [1.0.1] - 2026-06-13

### Fixes

- **job**: pin Chainguard python base by digest and refresh the grype allowlist (`1921713`)

## [1.0.0] - 2026-05-27

### Breaking changes

- rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)
