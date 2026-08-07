# Changelog

All notable changes to this component are documented here.

## [1.0.0] - 2026-08-07

### Breaking changes

- rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)

### Features

- **web**: render the login form as a React island (`d61dcc8`)
- **web**: convert the frontend to a React Router SPA (`c57878d`)
- cut a synchronized release baseline across all components (`eb7f6d3`)
- **ssr**: publish package metadata and a PEP 561 marker (`a7878b3`)
- **api,job,ssr,migrations**: declare the OCI annotations in the Dockerfiles (`7a1e881`)

### Fixes

- **deps**: update uvicorn[standard] requirement from >=0.32 to >=0.48.0 (`1b6d0d4`)
- **ssr**: bump python-multipart from 0.0.29 to 0.0.32 (`f77b970`)
- **ssr**: satisfy mypy --strict in app.py after the DevAwareStaticFiles refactor (`c75a9d4`)
- **ssr**: pin Chainguard python base by digest and refresh the grype allowlist (`0854500`)
- **ssr**: tighten the DevAwareStaticFiles docstring (`5fcddb4`)
- **deps**: bump fastapi from 0.136.3 to 0.137.0 (`796e513`)
- **ssr**: bump chainguard/python in /packages/ssr (`9efc673`)
- **ssr**: refresh grype allowlist against the current base image (`c808b5f`)
- **deps**: bump fastapi from 0.137.0 to 0.141.0 (`16c4ca4`)

### Dependencies

- Track `web` `1.0.0`
