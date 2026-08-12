# Changelog

All notable changes across components, aggregated per release.
Per-component details live under `packages/<comp>/CHANGELOG.md`.

## 2026-08-12

### Releases

- **docs** patch — 1.0.10 → 1.0.11  _(cascade from infra 0.2.0)_
- **infra** minor — 0.1.2 → 0.2.0

### Features

- **infra**: pick the provider and the cloud login from the environment config (`2cc9311`)

## 2026-08-12

### Releases

- **app** patch — 0.1.0 → 0.1.1
- **docs** patch — 1.0.9 → 1.0.10  _(cascade from app 0.1.1)_

### Fixes

- **app**: announce validation errors, and stop autocorrect on the username (`8b5ca0a`)

## 2026-08-12

### Releases

- **docs** patch — 1.0.8 → 1.0.9  _(cascade from infra-modules-example 0.2.0)_
- **infra** patch — 0.1.1 → 0.1.2  _(cascade from infra-modules-example 0.2.0)_
- **infra-modules-example** minor — 0.1.0 → 0.2.0

### Features

- **infra-modules-example**: carry the config version into the resource identity (`155e17a`)

## 2026-08-12

### Releases

- **docs** patch — 1.0.7 → 1.0.8  _(cascade from configs-staging)_

## 2026-08-12

### Releases

- **docs** patch — 1.0.6 → 1.0.7  _(cascade from configs-staging)_

## 2026-08-11

### Releases

- **docs** patch — 1.0.5 → 1.0.6  _(cascade from configs-staging)_
- **infra** patch — 0.1.0 → 0.1.1  _(cascade from infra-modules-network-vpc-gcp 0.2.0)_
- **infra-modules-network-vpc-gcp** minor — 0.1.0 → 0.2.0

### Features

- **infra-modules-network-vpc-gcp**: implement the VPC, without a way out by default (`da38756`)

## 2026-08-11

### Releases

- **gitops-staging** patch — 0.1.3 → 0.1.4

## 2026-08-11

### Releases

- **chart-api** minor — 1.0.1 → 1.1.0
- **docs** patch — 1.0.4 → 1.0.5  _(cascade from chart-api 1.1.0)_

### Features

- **chart-api**: make the NetworkPolicy narrowable from values (`3c4d19f`)

## 2026-08-11

### Releases

- **gitops-staging** patch — 0.1.2 → 0.1.3

## 2026-08-11

### Releases

- **chart-job** patch — 1.0.1 → 1.0.2  _(cascade from job 1.0.2)_
- **docs** patch — 1.0.3 → 1.0.4  _(cascade from job 1.0.2)_
- **job** patch — 1.0.1 → 1.0.2

### Fixes

- **job**: wait for the broker instead of dying when it is not up yet (`03af7a1`)

## 2026-08-11

### Releases

- **gitops-staging** patch — 0.1.1 → 0.1.2

## 2026-08-11

### Releases

- **chart-ssr** patch — 1.0.0 → 1.0.1  _(cascade from ssr 1.0.1)_
- **docs** patch — 1.0.2 → 1.0.3  _(cascade from ssr 1.0.1)_
- **ssr** patch — 1.0.0 → 1.0.1  _(cascade from web 1.0.1)_
- **web** patch — 1.0.0 → 1.0.1

### Fixes

- **web**: validate the server config before spreading it (`2328b54`)

## 2026-08-11

### Releases

- **gitops-staging** patch — 0.1.0 → 0.1.1

## 2026-08-11

### Releases

- **api** patch — 0.1.0 → 0.1.1  _(cascade from database 0.1.1)_
- **chart-api** patch — 1.0.0 → 1.0.1  _(cascade from api 0.1.1)_
- **chart-job** patch — 1.0.0 → 1.0.1  _(cascade from job 1.0.1)_
- **chart-migrations** patch — 0.1.0 → 0.1.1  _(cascade from migrations 0.1.1)_
- **database** patch — 0.1.0 → 0.1.1
- **docs** patch — 1.0.1 → 1.0.2  _(cascade from api 0.1.1)_
- **job** patch — 1.0.0 → 1.0.1  _(cascade from database 0.1.1)_
- **migrations** patch — 0.1.0 → 0.1.1  _(cascade from database 0.1.1)_

### Fixes

- **database**: roll back get_session when the caller raises (`8a201a5`)

## 2026-08-11

### Releases

- **docs** patch — 1.0.0 → 1.0.1  _(cascade from configs-staging)_

## 2026-08-11

### Releases

- **gitops-staging** minor — 0.0.0 → 0.1.0

### Features

- **gitops-staging**: flux layout with pinned staging and production (`799dccf`)

## 2026-08-11

### Releases

- **api** minor — 0.0.0 → 0.1.0  _(cascade from database 0.1.0)_
- **app** minor — 0.0.0 → 0.1.0  _(cascade from lib 0.1.0)_
- **chart-api** major — 0.0.0 → 1.0.0  _(cascade from api 0.1.0)_
- **chart-job** major — 0.0.0 → 1.0.0  _(cascade from job 1.0.0)_
- **chart-migrations** minor — 0.0.0 → 0.1.0  _(cascade from migrations 0.1.0)_
- **chart-ssr** major — 0.0.0 → 1.0.0  _(cascade from ssr 1.0.0)_
- **cli** minor — 0.0.0 → 0.1.0
- **database** minor — 0.0.0 → 0.1.0
- **docs** major — 0.0.0 → 1.0.0  _(cascade from api 0.1.0)_
- **gitops** minor — 0.0.0 → 0.1.0
- **infra** minor — 0.0.0 → 0.1.0  _(cascade from infra-modules-example 0.1.0)_
- **infra-bootstrap-aws** minor — 0.0.0 → 0.1.0
- **infra-bootstrap-gcp** minor — 0.0.0 → 0.1.0
- **infra-modules-dns-private-aws** minor — 0.0.0 → 0.1.0
- **infra-modules-dns-private-gcp** minor — 0.0.0 → 0.1.0
- **infra-modules-dns-public-aws** minor — 0.0.0 → 0.1.0
- **infra-modules-dns-public-gcp** minor — 0.0.0 → 0.1.0
- **infra-modules-example** minor — 0.0.0 → 0.1.0
- **infra-modules-k8s-cluster-aws** minor — 0.0.0 → 0.1.0
- **infra-modules-k8s-cluster-gcp** minor — 0.0.0 → 0.1.0
- **infra-modules-k8s-nodes-aws** minor — 0.0.0 → 0.1.0
- **infra-modules-k8s-nodes-gcp** minor — 0.0.0 → 0.1.0
- **infra-modules-network-addresses-private-aws** minor — 0.0.0 → 0.1.0
- **infra-modules-network-addresses-private-gcp** minor — 0.0.0 → 0.1.0
- **infra-modules-network-addresses-public-aws** minor — 0.0.0 → 0.1.0
- **infra-modules-network-addresses-public-gcp** minor — 0.0.0 → 0.1.0
- **infra-modules-network-firewall-aws** minor — 0.0.0 → 0.1.0
- **infra-modules-network-firewall-gcp** minor — 0.0.0 → 0.1.0
- **infra-modules-network-nat-aws** minor — 0.0.0 → 0.1.0
- **infra-modules-network-nat-gcp** minor — 0.0.0 → 0.1.0
- **infra-modules-network-routes-aws** minor — 0.0.0 → 0.1.0
- **infra-modules-network-routes-gcp** minor — 0.0.0 → 0.1.0
- **infra-modules-network-subnets-aws** minor — 0.0.0 → 0.1.0
- **infra-modules-network-subnets-gcp** minor — 0.0.0 → 0.1.0
- **infra-modules-network-vpc-aws** minor — 0.0.0 → 0.1.0
- **infra-modules-network-vpc-gcp** minor — 0.0.0 → 0.1.0
- **infra-modules-vms-proxy-aws** minor — 0.0.0 → 0.1.0
- **infra-modules-vms-proxy-gcp** minor — 0.0.0 → 0.1.0
- **job** major — 0.0.0 → 1.0.0  _(cascade from database 0.1.0)_
- **lib** minor — 0.0.0 → 0.1.0
- **migrations** minor — 0.0.0 → 0.1.0  _(cascade from database 0.1.0)_
- **ssr** major — 0.0.0 → 1.0.0  _(cascade from web 1.0.0)_
- **web** major — 0.0.0 → 1.0.0  _(cascade from lib 0.1.0)_

### Breaking changes

- **chart-api**: rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)
- **chart-job**: rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)
- **chart-ssr**: rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)
- **docs**: rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)
- **job**: rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)
- **ssr**: rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)
- **web**: rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)

### Features

- **api**: scaffold fastapi service with healthz and oidc discovery (`57738f2`)
- **api**: add Dockerfile and helm chart (`c215f8e`)
- **api**: add debian packaging with systemd unit (`c308083`)
- **api**: mark all packages as 3.0 (native) source format (`23f6712`)
- **api**: harden shomer-api systemd unit with full sandbox + syscall filter (`78877f3`)
- **api**: ship AppStream metainfo + hicolor icon so AppCenter shows the package (`0387af5`)
- **api**: advertise PKCE in the OIDC discovery document (`04de3e6`)
- **api**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **api**: publish package metadata and a PEP 561 marker (`fc90063`)
- **api**: declare the OCI annotations in the Dockerfiles (`7a1e881`)
- **app**: scaffold the React Native (bare) mobile app (`56ed132`)
- **app**: publish signed store builds when secrets are configured (`31ae54b`)
- **app**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **app**: publish package metadata (`e6db771`)
- **chart-api**: add Dockerfile and helm chart (`c215f8e`)
- **chart-api**: set Chart.yaml icon (ArtifactHub + Lens render the shield) (`f1501f6`)
- **chart-api**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **chart-api**: declare home, sources and maintainers (`29cf326`)
- **chart-api**: sign charts and .deb, verify every signature, pin composite actions (`cedacec`)
- **chart-api**: make the Sigstore endpoints configurable (`5d9cffb`)
- **chart-job**: declare home, sources and maintainers (`048b482`)
- **chart-job**: sign charts and .deb, verify every signature, pin composite actions (`cedacec`)
- **chart-job**: make the Sigstore endpoints configurable (`5d9cffb`)
- **chart-migrations**: add shomer-migrations package (`dfa8e59`)
- **chart-migrations**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **chart-migrations**: declare home, sources and maintainers (`66c1a46`)
- **chart-migrations**: sign charts and .deb, verify every signature, pin composite actions (`cedacec`)
- **chart-migrations**: make the Sigstore endpoints configurable (`5d9cffb`)
- **chart-ssr**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **chart-ssr**: declare home, sources and maintainers (`75333c2`)
- **chart-ssr**: sign charts and .deb, verify every signature, pin composite actions (`cedacec`)
- **chart-ssr**: make the Sigstore endpoints configurable (`5d9cffb`)
- **cli**: scaffold typer cli with health probe (`a72f119`)
- **cli**: add debian packaging (`6644410`)
- **cli**: mark all packages as 3.0 (native) source format (`23f6712`)
- **cli**: ship AppStream metainfo + hicolor icon so AppCenter shows the package (`352ae4d`)
- **cli**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **cli**: publish package metadata and a PEP 561 marker (`61c0347`)
- **database**: add shomer-database package (`0a69c40`)
- **database**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **database**: publish package metadata (`118b192`)
- **docs**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **docs**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)
- **docs**: give the shared Flux wiring its own version (`5424aad`)
- **docs**: bootstrap the state backend for AWS and GCP (`fc631c5`)
- **docs**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **gitops**: flux layout with pinned staging and production (`799dccf`)
- **gitops**: promotion workflows for staging and production (`745a6b6`)
- **infra**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)
- **infra**: stamp the deployed config version onto resources (`6fa50f9`)
- **infra**: lint the terragrunt wiring, not just its formatting (`f72d10d`)
- **infra**: bootstrap the state backend for AWS and GCP (`fc631c5`)
- **infra**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra**: release every terraform module, and waive the OpenSSL High (`f14d55c`)
- **infra-bootstrap-aws**: bootstrap the state backend for AWS and GCP (`fc631c5`)
- **infra-bootstrap-gcp**: bootstrap the state backend for AWS and GCP (`fc631c5`)
- **infra-modules-dns-private-aws**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-dns-private-gcp**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-dns-public-aws**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-dns-public-gcp**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-example**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)
- **infra-modules-example**: manage a terraform_data resource so the plan has a diff (`2cd3ad8`)
- **infra-modules-k8s-cluster-aws**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-k8s-cluster-gcp**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-k8s-nodes-aws**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-k8s-nodes-gcp**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-network-addresses-private-aws**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-network-addresses-private-gcp**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-network-addresses-public-aws**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-network-addresses-public-gcp**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-network-firewall-aws**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-network-firewall-gcp**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-network-nat-aws**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-network-nat-gcp**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-network-routes-aws**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-network-routes-gcp**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-network-subnets-aws**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-network-subnets-gcp**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-network-vpc-aws**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-network-vpc-gcp**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-vms-proxy-aws**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **infra-modules-vms-proxy-gcp**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **job**: run as a celery worker backed by redis (`9403e09`)
- **job**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **job**: publish package metadata and a PEP 561 marker (`f807ec8`)
- **job**: declare the OCI annotations in the Dockerfiles (`7a1e881`)
- **lib**: add shared @shomer/lib package and npm workspace root (`f89a567`)
- **lib**: export the password length bounds (`a80b5a7`)
- **lib**: add normalizeUsername helper (`c6860a0`)
- **lib**: add sanitizeCredentials (`7896980`)
- **lib**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **lib**: publish package metadata (`9fa18a7`)
- **migrations**: add shomer-migrations package (`dfa8e59`)
- **migrations**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **migrations**: publish package metadata (`98bbd64`)
- **migrations**: declare the OCI annotations in the Dockerfiles (`7a1e881`)
- **migrations**: ship shomer-migrations as a .deb (`075ebc7`)
- **ssr**: render the login form as a React island (`d61dcc8`)
- **ssr**: convert the frontend to a React Router SPA (`c57878d`)
- **ssr**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **ssr**: publish package metadata and a PEP 561 marker (`a7878b3`)
- **ssr**: declare the OCI annotations in the Dockerfiles (`7a1e881`)
- **web**: scaffold fastapi + jinja2 web frontend with login stub (`725ddbb`)
- **web**: docker compose stack with watch for the whole workspace (`04b31b0`)
- **web**: minify in every mode, inline sourcemap in dev only (`24b88c1`)
- **web**: render the login form as a React island (`d61dcc8`)
- **web**: convert the frontend to a React Router SPA (`c57878d`)
- **web**: cut a synchronized release baseline across all components (`eb7f6d3`)
- **web**: publish package metadata (`612a5fd`)

### Fixes

- **api**: install systemd unit to usr/lib/systemd/system (usrmerge-correct path) (`8bd422a`)
- **api**: add debian/copyright (DEP-5, MIT) — clears lintian E:no-copyright-file (`1955ed2`)
- **api**: add DevicePolicy=closed + IPAddressAllow=any (kills 0.3 badness) (`788426d`)
- **api**: use explicit CIDR ranges in IPAddressAllow (systemd-analyze ignores 'any') (`dedb918`)
- **api**: add IPAddressDeny=any (sets deny_all flag systemd-analyze credits) (`487ea3a`)
- **api**: suppress hadolint DL3007 (Chainguard images use rolling :latest by design) (`beedf7f`)
- **api**: update uvicorn[standard] requirement from >=0.32 to >=0.48.0 (`1b6d0d4`)
- **api**: pin Chainguard python base by digest and refresh the grype allowlist (`263bcef`)
- **api**: extract the OIDC issuer placeholder into a module constant (`1cce667`)
- **api**: disambiguate the FastAPI title from the ssr surface (`de18a83`)
- **api**: tag the healthz payload with the service identifier (`386848d`)
- **api**: advertise `scopes_supported` in the OIDC discovery document (`8c4567b`)
- **api**: bump chainguard/python in /packages/api (`664c254`)
- **api**: bump fastapi from 0.136.3 to 0.137.0 (`796e513`)
- **api**: refresh grype allowlist against the current base image (`4f52e87`)
- **api**: bump fastapi from 0.137.0 to 0.141.0 (`16c4ca4`)
- **app**: bump react from 19.2.3 to 19.2.7 in /packages/app (`1692fa6`)
- **app**: unblock app-sbom and app-mobsfscan (`681450e`)
- **app**: pin the Gradle wrapper to 9.3.1 for React Native 0.86 (`b1239dc`)
- **app**: make the Maestro e2e flow pass on Android and iOS (`194ee5d`)
- **app**: submit the e2e login via the keyboard return key (`0f7b90d`)
- **app**: pin Babel 7 and Jest 29 for React Native 0.86 (`3186e94`)
- **app**: clear the high-severity advisories in the app dependency tree (`00ffff5`)
- **app**: raise the app overrides past two new high-severity advisories (`7d4a615`)
- **chart-api**: harden Deployment (securityContext, NetworkPolicy, RO root, no SA token) (`26c049a`)
- **chart-api**: describe what the chart actually deploys (`cb73a50`)
- **chart-job**: describe what the chart actually deploys (`d2aeb4d`)
- **chart-job**: raise job memory limit to 256Mi (`c1ac65c`)
- **chart-migrations**: add a baseline NetworkPolicy for the migration pod (`a45f2ad`)
- **chart-ssr**: collapse the line-wrapped description into one line (`681ce23`)
- **cli**: add debian/copyright (DEP-5, MIT) — clears lintian E:no-copyright-file (`3779ba9`)
- **cli**: bump typer from 0.26.4 to 0.26.7 (`d8d648b`)
- **cli**: clarify the operator workflow in the module docstring (`38f4e01`)
- **docs**: use [project.theme] schema so logo and palette take effect (`4a30d51`)
- **docs**: list shomer-ssr in the components table (`c71a40a`)
- **docs**: list every terraform module in VERSION and in the docs (`3ceb7d8`)
- **infra**: pin every action the infra jobs use, drop action-terragrunt (`fb515f9`)
- **infra**: list every terraform module in VERSION and in the docs (`3ceb7d8`)
- **infra**: make the terragrunt wiring depend on the modules it consumes (`41b95a6`)
- **infra**: make release-bump wait on every terraform module check (`0214fd4`)
- **job**: pin Chainguard python base by digest and refresh the grype allowlist (`1921713`)
- **job**: log the iteration index from tick() (`0400c5e`)
- **job**: satisfy mypy --strict on the celery worker (`2afbe4e`)
- **job**: write the celery beat schedule to a writable path (`a46f7e8`)
- **job**: bump chainguard/python in /packages/job (`d96a244`)
- **job**: refresh grype allowlist against the current base image (`38cb5d1`)
- **migrations**: document the shomer-migrate entrypoint (`987f120`)
- **migrations**: refresh grype allowlist against the current base image (`869685a`)
- **ssr**: update uvicorn[standard] requirement from >=0.32 to >=0.48.0 (`1b6d0d4`)
- **ssr**: bump python-multipart from 0.0.29 to 0.0.32 (`f77b970`)
- **ssr**: satisfy mypy --strict in app.py after the DevAwareStaticFiles refactor (`c75a9d4`)
- **ssr**: pin Chainguard python base by digest and refresh the grype allowlist (`0854500`)
- **ssr**: tighten the DevAwareStaticFiles docstring (`5fcddb4`)
- **ssr**: bump fastapi from 0.136.3 to 0.137.0 (`796e513`)
- **ssr**: bump chainguard/python in /packages/ssr (`9efc673`)
- **ssr**: refresh grype allowlist against the current base image (`c808b5f`)
- **ssr**: bump fastapi from 0.137.0 to 0.141.0 (`16c4ca4`)
- **web**: migrate biome.json to v2.x schema and allow Jinja interpolation (`e643a20`)
- **web**: uv cache path + don't rmdir the templates bind mount (`72f9242`)
- **web**: rename the local DOM lookup from `slot` to `errorSlot` (`70379e7`)
- **web**: cap password input length client-side to short-circuit DoS-shaped inputs (`4c7da47`)
- **web**: bump react-dom from 19.2.7 to 19.2.8 (`a1f4b10`)
- **web**: bump react-router-dom from 7.18.0 to 7.18.2 (`2ec5272`)
