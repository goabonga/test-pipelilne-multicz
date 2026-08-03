# Changelog

All notable changes across components, aggregated per release.
Per-component details live under `packages/<comp>/CHANGELOG.md`.

## 2026-08-03

### Releases

- **gitops-production** patch — 0.1.1 → 0.1.2

## 2026-08-03

### Releases

- **gitops-production** patch — 0.1.0 → 0.1.1

## 2026-07-31

### Releases

- **configs-production** minor — 0.0.0 → 0.1.0
- **configs-staging** minor — 0.0.0 → 0.1.0
- **docs** patch — 1.2.13 → 1.2.14  _(cascade from configs-staging 0.1.0)_
- **gitops-production** minor — 0.0.0 → 0.1.0
- **gitops-staging** minor — 0.0.0 → 0.1.0

### Features

- **configs-production**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)
- **configs-staging**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)
- **gitops-production**: flux layout with pinned staging and production (`799dccf`)
- **gitops-staging**: flux layout with pinned staging and production (`799dccf`)

## 2026-07-31

### Releases

- **docs** patch — 1.2.12 → 1.2.13  _(cascade from configs-staging)_

## 2026-07-31

### Releases

- **docs** patch — 1.2.11 → 1.2.12  _(cascade from configs-staging)_

## 2026-07-31

### Releases

- **docs** patch — 1.2.10 → 1.2.11  _(cascade from configs-staging)_

## 2026-07-31

### Releases

- **chart-api** minor — 1.3.1 → 1.4.0
- **chart-job** minor — 1.2.1 → 1.3.0
- **chart-migrations** minor — 0.4.1 → 0.5.0
- **chart-ssr** minor — 1.3.1 → 1.4.0
- **docs** patch — 1.2.9 → 1.2.10  _(cascade from chart-api 1.4.0)_

### Features

- **chart-api**: make the Sigstore endpoints configurable (`5d9cffb`)
- **chart-job**: make the Sigstore endpoints configurable (`5d9cffb`)
- **chart-migrations**: make the Sigstore endpoints configurable (`5d9cffb`)
- **chart-ssr**: make the Sigstore endpoints configurable (`5d9cffb`)

## 2026-07-31

### Releases

- **api** minor — 0.4.0 → 0.5.0
- **chart-api** patch — 1.3.0 → 1.3.1  _(cascade from api 0.5.0)_
- **chart-job** patch — 1.2.0 → 1.2.1  _(cascade from job 1.4.0)_
- **chart-migrations** patch — 0.4.0 → 0.4.1  _(cascade from migrations 0.4.0)_
- **chart-ssr** patch — 1.3.0 → 1.3.1  _(cascade from ssr 1.4.0)_
- **docs** patch — 1.2.8 → 1.2.9  _(cascade from api 0.5.0)_
- **job** minor — 1.3.0 → 1.4.0
- **migrations** minor — 0.3.0 → 0.4.0
- **ssr** minor — 1.3.0 → 1.4.0

### Features

- **api**: declare the OCI annotations in the Dockerfiles (`7a1e881`)
- **job**: declare the OCI annotations in the Dockerfiles (`7a1e881`)
- **migrations**: declare the OCI annotations in the Dockerfiles (`7a1e881`)
- **ssr**: declare the OCI annotations in the Dockerfiles (`7a1e881`)

## 2026-07-31

### Releases

- **docs** patch — 1.2.7 → 1.2.8  _(cascade from configs-staging)_

## 2026-07-31

### Releases

- **docs** patch — 1.2.6 → 1.2.7  _(cascade from configs-staging)_

## 2026-07-31

### Releases

- **chart-api** minor — 1.2.0 → 1.3.0
- **chart-job** minor — 1.1.0 → 1.2.0
- **chart-migrations** minor — 0.3.0 → 0.4.0
- **chart-ssr** minor — 1.2.0 → 1.3.0
- **docs** patch — 1.2.5 → 1.2.6  _(cascade from chart-api 1.3.0)_

### Features

- **chart-api**: sign charts and .deb, verify every signature, pin composite actions (`cedacec`)
- **chart-job**: sign charts and .deb, verify every signature, pin composite actions (`cedacec`)
- **chart-migrations**: sign charts and .deb, verify every signature, pin composite actions (`cedacec`)
- **chart-ssr**: sign charts and .deb, verify every signature, pin composite actions (`cedacec`)

## 2026-07-31

### Releases

- **api** minor — 0.3.2 → 0.4.0  _(cascade from database 0.3.0)_
- **app** minor — 0.2.1 → 0.3.0  _(cascade from lib 0.6.0)_
- **chart-api** minor — 1.1.2 → 1.2.0  _(cascade from api 0.4.0)_
- **chart-job** minor — 1.0.7 → 1.1.0  _(cascade from job 1.3.0)_
- **chart-migrations** minor — 0.2.1 → 0.3.0  _(cascade from migrations 0.3.0)_
- **chart-ssr** minor — 1.1.3 → 1.2.0  _(cascade from ssr 1.3.0)_
- **cli** minor — 0.2.0 → 0.3.0
- **database** minor — 0.2.0 → 0.3.0
- **docs** patch — 1.2.4 → 1.2.5  _(cascade from api 0.4.0)_
- **infra** minor — 0.2.0 → 0.3.0
- **job** minor — 1.2.1 → 1.3.0  _(cascade from database 0.3.0)_
- **lib** minor — 0.5.0 → 0.6.0
- **migrations** minor — 0.2.1 → 0.3.0  _(cascade from database 0.3.0)_
- **ssr** minor — 1.2.3 → 1.3.0  _(cascade from web 1.4.0)_
- **web** minor — 1.3.1 → 1.4.0  _(cascade from lib 0.6.0)_

### Features

- **api**: publish package metadata and a PEP 561 marker (`fc90063`)
- **app**: publish package metadata (`e6db771`)
- **chart-api**: declare home, sources and maintainers (`29cf326`)
- **chart-job**: declare home, sources and maintainers (`048b482`)
- **chart-migrations**: declare home, sources and maintainers (`66c1a46`)
- **chart-ssr**: declare home, sources and maintainers (`75333c2`)
- **cli**: publish package metadata and a PEP 561 marker (`61c0347`)
- **database**: publish package metadata (`118b192`)
- **infra**: stamp the deployed config version onto resources (`6fa50f9`)
- **job**: publish package metadata and a PEP 561 marker (`f807ec8`)
- **lib**: publish package metadata (`9fa18a7`)
- **migrations**: publish package metadata (`98bbd64`)
- **ssr**: publish package metadata and a PEP 561 marker (`a7878b3`)
- **web**: publish package metadata (`612a5fd`)

## 2026-07-31

### Releases

- **docs** patch — 1.2.3 → 1.2.4  _(cascade from infra-modules-example 0.3.0)_
- **infra-modules-example** minor — 0.2.0 → 0.3.0

### Features

- **infra-modules-example**: manage a terraform_data resource so the plan has a diff (`2cd3ad8`)

## 2026-07-31

### Releases

- **docs** patch — 1.2.2 → 1.2.3  _(cascade from configs-staging)_

## 2026-07-31

### Releases

- **docs** patch — 1.2.1 → 1.2.2  _(cascade from configs-staging)_

## 2026-07-31

### Releases

- **docs** patch — 1.2.0 → 1.2.1  _(cascade from infra 0.2.0)_
- **infra** minor — 0.1.0 → 0.2.0
- **infra-modules-example** minor — 0.1.0 → 0.2.0

### Features

- **infra**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)
- **infra-modules-example**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)

### Fixes

- **infra**: pin every action the infra jobs use, drop action-terragrunt (`fb515f9`)

## 2026-07-30

### Releases

- **docs** minor — 1.1.6 → 1.2.0  _(cascade from infra 0.1.0)_
- **infra** minor — 0.0.0 → 0.1.0
- **infra-modules-example** minor — 0.0.0 → 0.1.0

### Features

- **docs**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)
- **infra**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)
- **infra-modules-example**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)

## 2026-07-29

### Releases

- **api** patch — 0.3.1 → 0.3.2
- **chart-api** patch — 1.1.1 → 1.1.2  _(cascade from api 0.3.2)_
- **chart-ssr** patch — 1.1.2 → 1.1.3  _(cascade from ssr 1.2.3)_
- **docs** patch — 1.1.5 → 1.1.6  _(cascade from api 0.3.2)_
- **ssr** patch — 1.2.2 → 1.2.3

### Fixes

- **api**: bump fastapi from 0.137.0 to 0.141.0 (`16c4ca4`)
- **ssr**: bump fastapi from 0.137.0 to 0.141.0 (`16c4ca4`)

## 2026-07-29

### Releases

- **app** patch — 0.2.0 → 0.2.1
- **docs** patch — 1.1.4 → 1.1.5  _(cascade from app 0.2.1)_

### Fixes

- **app**: clear the high-severity advisories in the app dependency tree (`00ffff5`)

## 2026-07-29

### Releases

- **chart-ssr** patch — 1.1.1 → 1.1.2  _(cascade from ssr 1.2.2)_
- **docs** patch — 1.1.3 → 1.1.4  _(cascade from ssr 1.2.2)_
- **ssr** patch — 1.2.1 → 1.2.2  _(cascade from web 1.3.1)_
- **web** patch — 1.3.0 → 1.3.1

### Fixes

- **web**: bump react-dom from 19.2.7 to 19.2.8 (`a1f4b10`)

## 2026-07-29

### Releases

- **chart-migrations** patch — 0.2.0 → 0.2.1  _(cascade from migrations 0.2.1)_
- **chart-ssr** patch — 1.1.0 → 1.1.1  _(cascade from ssr 1.2.1)_
- **docs** patch — 1.1.2 → 1.1.3  _(cascade from migrations 0.2.1)_
- **migrations** patch — 0.2.0 → 0.2.1
- **ssr** patch — 1.2.0 → 1.2.1

### Fixes

- **migrations**: refresh grype allowlist against the current base image (`869685a`)
- **ssr**: refresh grype allowlist against the current base image (`c808b5f`)

## 2026-07-28

### Releases

- **chart-job** patch — 1.0.6 → 1.0.7  _(cascade from job 1.2.1)_
- **docs** patch — 1.1.1 → 1.1.2  _(cascade from job 1.2.1)_
- **job** patch — 1.2.0 → 1.2.1

### Fixes

- **job**: refresh grype allowlist against the current base image (`38cb5d1`)

## 2026-07-28

### Releases

- **api** patch — 0.3.0 → 0.3.1
- **chart-api** patch — 1.1.0 → 1.1.1  _(cascade from api 0.3.1)_
- **docs** patch — 1.1.0 → 1.1.1  _(cascade from api 0.3.1)_

### Fixes

- **api**: refresh grype allowlist against the current base image (`4f52e87`)

## 2026-07-19

### Releases

- **api** minor — 0.2.5 → 0.3.0  _(cascade from database 0.2.0)_
- **app** minor — 0.1.4 → 0.2.0  _(cascade from lib 0.5.0)_
- **chart-api** minor — 1.0.8 → 1.1.0  _(cascade from api 0.3.0)_
- **chart-job** patch — 1.0.5 → 1.0.6  _(cascade from job 1.2.0)_
- **chart-migrations** minor — 0.1.1 → 0.2.0  _(cascade from migrations 0.2.0)_
- **chart-ssr** minor — 1.0.9 → 1.1.0  _(cascade from ssr 1.2.0)_
- **cli** minor — 0.1.2 → 0.2.0
- **database** minor — 0.1.0 → 0.2.0
- **docs** minor — 1.0.10 → 1.1.0  _(cascade from api 0.3.0)_
- **job** minor — 1.1.1 → 1.2.0  _(cascade from database 0.2.0)_
- **lib** minor — 0.4.0 → 0.5.0
- **migrations** minor — 0.1.1 → 0.2.0  _(cascade from database 0.2.0)_
- **ssr** minor — 1.1.3 → 1.2.0  _(cascade from web 1.3.0)_
- **web** minor — 1.2.3 → 1.3.0  _(cascade from lib 0.5.0)_

### Features

- **api**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **app**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **chart-api**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **chart-migrations**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **chart-ssr**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **cli**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **database**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **docs**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **job**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **lib**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **migrations**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **ssr**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **web**: cut a synchronized release baseline across all components (`eb7f6d3`)

### Fixes

- **chart-job**: raise job memory limit to 256Mi (`c1ac65c`)

## 2026-06-27

### Releases

- **app** patch — 0.1.3 → 0.1.4
- **docs** patch — 1.0.9 → 1.0.10  _(cascade from app 0.1.4)_

### Fixes

- **app**: pin Babel 7 and Jest 29 for React Native 0.86 (`3186e94`)

## 2026-06-21

### Releases

- **chart-migrations** patch — 0.1.0 → 0.1.1  _(cascade from migrations 0.1.1)_
- **docs** patch — 1.0.8 → 1.0.9  _(cascade from migrations 0.1.1)_
- **migrations** patch — 0.1.0 → 0.1.1

### Fixes

- **migrations**: document the shomer-migrate entrypoint (`987f120`)

## 2026-06-21

### Releases

- **app** patch — 0.1.2 → 0.1.3  _(cascade from lib 0.4.0)_
- **chart-ssr** patch — 1.0.8 → 1.0.9  _(cascade from ssr 1.1.3)_
- **docs** patch — 1.0.7 → 1.0.8  _(cascade from web 1.2.3)_
- **lib** minor — 0.3.0 → 0.4.0
- **ssr** patch — 1.1.2 → 1.1.3  _(cascade from web 1.2.3)_
- **web** patch — 1.2.2 → 1.2.3  _(cascade from lib 0.4.0)_

### Features

- **lib**: add sanitizeCredentials (`7896980`)

## 2026-06-21

### Releases

- **app** patch — 0.1.1 → 0.1.2  _(cascade from lib 0.3.0)_
- **chart-ssr** patch — 1.0.7 → 1.0.8  _(cascade from ssr 1.1.2)_
- **docs** patch — 1.0.6 → 1.0.7  _(cascade from web 1.2.2)_
- **lib** minor — 0.2.0 → 0.3.0
- **ssr** patch — 1.1.1 → 1.1.2  _(cascade from web 1.2.2)_
- **web** patch — 1.2.1 → 1.2.2  _(cascade from lib 0.3.0)_

### Features

- **lib**: add normalizeUsername helper (`c6860a0`)

## 2026-06-21

### Releases

- **app** patch — 0.1.0 → 0.1.1  _(cascade from lib 0.2.0)_
- **chart-ssr** patch — 1.0.6 → 1.0.7  _(cascade from ssr 1.1.1)_
- **docs** patch — 1.0.5 → 1.0.6  _(cascade from web 1.2.1)_
- **lib** minor — 0.1.0 → 0.2.0
- **ssr** patch — 1.1.0 → 1.1.1  _(cascade from web 1.2.1)_
- **web** patch — 1.2.0 → 1.2.1  _(cascade from lib 0.2.0)_

### Features

- **lib**: export the password length bounds (`a80b5a7`)

## 2026-06-21

### Releases

- **api** patch — 0.2.4 → 0.2.5
- **app** minor — 0.0.0 → 0.1.0  _(cascade from lib 0.1.0)_
- **chart-api** patch — 1.0.7 → 1.0.8  _(cascade from api 0.2.5)_
- **chart-job** patch — 1.0.4 → 1.0.5  _(cascade from job 1.1.1)_
- **chart-ssr** patch — 1.0.5 → 1.0.6  _(cascade from ssr 1.1.0)_
- **docs** patch — 1.0.4 → 1.0.5  _(cascade from api 0.2.5)_
- **job** patch — 1.1.0 → 1.1.1
- **lib** minor — 0.0.0 → 0.1.0
- **ssr** minor — 1.0.5 → 1.1.0  _(cascade from web 1.2.0)_
- **web** minor — 1.1.2 → 1.2.0  _(cascade from lib 0.1.0)_

### Features

- **app**: scaffold the React Native (bare) mobile app (`56ed132`)
- **app**: publish signed store builds when secrets are configured (`31ae54b`)
- **lib**: add shared @shomer/lib package and npm workspace root (`f89a567`)
- **ssr**: render the login form as a React island (`d61dcc8`)
- **ssr**: convert the frontend to a React Router SPA (`c57878d`)
- **web**: render the login form as a React island (`d61dcc8`)
- **web**: convert the frontend to a React Router SPA (`c57878d`)

### Fixes

- **api**: bump chainguard/python in /packages/api (`664c254`)
- **api**: bump fastapi from 0.136.3 to 0.137.0 (`796e513`)
- **app**: bump react from 19.2.3 to 19.2.7 in /packages/app (`1692fa6`)
- **app**: unblock app-sbom and app-mobsfscan (`681450e`)
- **app**: pin the Gradle wrapper to 9.3.1 for React Native 0.86 (`b1239dc`)
- **app**: make the Maestro e2e flow pass on Android and iOS (`194ee5d`)
- **app**: submit the e2e login via the keyboard return key (`0f7b90d`)
- **job**: write the celery beat schedule to a writable path (`a46f7e8`)
- **job**: bump chainguard/python in /packages/job (`d96a244`)
- **ssr**: bump fastapi from 0.136.3 to 0.137.0 (`796e513`)
- **ssr**: bump chainguard/python in /packages/ssr (`9efc673`)

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
