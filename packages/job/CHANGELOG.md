# Changelog

All notable changes to this component are documented here.

## [1.0.1] - 2026-08-11

### Dependencies

- Track `database` `0.1.1`

## [1.0.0] - 2026-08-11

### Breaking changes

- rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)

### Features

- **job**: run as a celery worker backed by redis (`9403e09`)
- cut a synchronized release baseline across all components (`eb7f6d3`)
- **job**: publish package metadata and a PEP 561 marker (`f807ec8`)
- **api,job,ssr,migrations**: declare the OCI annotations in the Dockerfiles (`7a1e881`)

### Fixes

- **job**: pin Chainguard python base by digest and refresh the grype allowlist (`1921713`)
- **job**: log the iteration index from tick() (`0400c5e`)
- **job**: satisfy mypy --strict on the celery worker (`2afbe4e`)
- **job**: write the celery beat schedule to a writable path (`a46f7e8`)
- **job**: bump chainguard/python in /packages/job (`d96a244`)
- **job**: refresh grype allowlist against the current base image (`38cb5d1`)

### Dependencies

- Track `database` `0.1.0`
