# Changelog

All notable changes to this component are documented here.

## [1.0.0] - 2026-08-09

### Breaking changes

- rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)

### Features

- cut a synchronized release baseline across all components (`eb7f6d3`)
- **chart-ssr**: declare home, sources and maintainers (`75333c2`)
- **ci**: sign charts and .deb, verify every signature, pin composite actions (`cedacec`)
- **chart-api,chart-job,chart-ssr,chart-migrations**: make the Sigstore endpoints configurable (`5d9cffb`)

### Fixes

- **chart-ssr**: collapse the line-wrapped description into one line (`681ce23`)

### Dependencies

- Track `ssr` `1.0.0`
