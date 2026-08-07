# Changelog

All notable changes to this component are documented here.

## [1.0.0] - 2026-08-07

### Breaking changes

- rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)

### Features

- **chart-job**: declare home, sources and maintainers (`048b482`)
- **ci**: sign charts and .deb, verify every signature, pin composite actions (`cedacec`)
- **chart-api,chart-job,chart-ssr,chart-migrations**: make the Sigstore endpoints configurable (`5d9cffb`)

### Fixes

- **chart-job**: describe what the chart actually deploys (`d2aeb4d`)
- **chart-job**: raise job memory limit to 256Mi (`c1ac65c`)

### Dependencies

- Track `job` `1.0.0`
