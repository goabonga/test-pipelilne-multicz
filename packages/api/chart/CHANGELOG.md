# Changelog

All notable changes to this component are documented here.

## [1.0.1] - 2026-06-13

### Dependencies

- Track `api` `0.1.1`

## [1.0.0] - 2026-05-27

### Breaking changes

- rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)

### Features

- **api**: add Dockerfile and helm chart (`c215f8e`)
- **chart-api**: set Chart.yaml icon (ArtifactHub + Lens render the shield) (`f1501f6`)

### Fixes

- **chart-api**: harden Deployment (securityContext, NetworkPolicy, RO root, no SA token) (`26c049a`)

### Dependencies

- Track `api` `0.1.0`
