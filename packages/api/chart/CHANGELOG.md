# Changelog

All notable changes to this component are documented here.

## [1.0.0] - 2026-08-11

### Breaking changes

- rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)

### Features

- **api**: add Dockerfile and helm chart (`c215f8e`)
- **chart-api**: set Chart.yaml icon (ArtifactHub + Lens render the shield) (`f1501f6`)
- cut a synchronized release baseline across all components (`eb7f6d3`)
- **chart-api**: declare home, sources and maintainers (`29cf326`)
- **ci**: sign charts and .deb, verify every signature, pin composite actions (`cedacec`)
- **chart-api,chart-job,chart-ssr,chart-migrations**: make the Sigstore endpoints configurable (`5d9cffb`)

### Fixes

- **chart-api**: harden Deployment (securityContext, NetworkPolicy, RO root, no SA token) (`26c049a`)
- **chart-api**: describe what the chart actually deploys (`cb73a50`)

### Dependencies

- Track `api` `0.1.0`
