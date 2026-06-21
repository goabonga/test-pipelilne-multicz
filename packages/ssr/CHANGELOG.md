# Changelog

All notable changes to this component are documented here.

## [1.1.1] - 2026-06-21

### Dependencies

- Track `web` `1.2.1`

## [1.1.0] - 2026-06-21

### Features

- **web**: render the login form as a React island (`d61dcc8`)
- **web**: convert the frontend to a React Router SPA (`c57878d`)

### Fixes

- **deps**: bump fastapi from 0.136.3 to 0.137.0 (`796e513`)
- **ssr**: bump chainguard/python in /packages/ssr (`9efc673`)

### Dependencies

- Track `web` `1.2.0`

## [1.0.5] - 2026-06-14

### Dependencies

- Track `web` `1.1.2`

## [1.0.4] - 2026-06-13

### Fixes

- **ssr**: tighten the DevAwareStaticFiles docstring (`5fcddb4`)

### Dependencies

- Track `web` `1.1.1`

## [1.0.3] - 2026-06-13

### Fixes

- **ssr**: satisfy mypy --strict in app.py after the DevAwareStaticFiles refactor (`c75a9d4`)
- **ssr**: pin Chainguard python base by digest and refresh the grype allowlist (`0854500`)

### Dependencies

- Track `web` `1.1.0`

## [1.0.3] - 2026-06-13

### Fixes

- **ssr**: satisfy mypy --strict in app.py after the DevAwareStaticFiles refactor (`c75a9d4`)

### Dependencies

- Track `web` `1.1.0`

## [1.0.2] - 2026-06-13

### Fixes

- **ssr**: bump python-multipart from 0.0.29 to 0.0.32 (`f77b970`)

## [1.0.1] - 2026-06-13

### Fixes

- **deps**: update uvicorn[standard] requirement from >=0.32 to >=0.48.0 (`1b6d0d4`)

### Dependencies

- Track `web` `1.0.1`

## [1.0.0] - 2026-05-27

### Breaking changes

- rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)

### Fixes

- **deps**: update uvicorn[standard] requirement from >=0.32 to >=0.48.0 (`345fe1b`)

### Dependencies

- Track `web` `1.0.0`
