# Changelog

All notable changes to this component are documented here.

## [0.2.4] - 2026-06-18

### Dependencies

- Track `database` `0.1.0`

## [0.2.3] - 2026-06-14

### Fixes

- **api**: advertise `scopes_supported` in the OIDC discovery document (`8c4567b`)

## [0.2.2] - 2026-06-13

### Fixes

- **api**: tag the healthz payload with the service identifier (`386848d`)

## [0.2.1] - 2026-06-13

### Fixes

- **api**: disambiguate the FastAPI title from the ssr surface (`de18a83`)

## [0.2.0] - 2026-06-13

### Features

- **api**: advertise PKCE in the OIDC discovery document (`04de3e6`)

### Fixes

- **api**: extract the OIDC issuer placeholder into a module constant (`1cce667`)

## [0.1.2] - 2026-06-13

### Fixes

- **api**: pin Chainguard python base by digest and refresh the grype allowlist (`263bcef`)

## [0.1.1] - 2026-06-13

### Fixes

- **deps**: update uvicorn[standard] requirement from >=0.32 to >=0.48.0 (`1b6d0d4`)

## [0.1.0] - 2026-05-27

### Features

- **api**: scaffold fastapi service with healthz and oidc discovery (`57738f2`)
- **api**: add Dockerfile and helm chart (`c215f8e`)
- **api**: add debian packaging with systemd unit (`c308083`)
- **debian**: mark all packages as 3.0 (native) source format (`23f6712`)
- **api**: harden shomer-api systemd unit with full sandbox + syscall filter (`78877f3`)
- **api**: ship AppStream metainfo + hicolor icon so AppCenter shows the package (`0387af5`)

### Fixes

- **api,worker,web**: install systemd unit to usr/lib/systemd/system (usrmerge-correct path) (`8bd422a`)
- **api**: add debian/copyright (DEP-5, MIT) — clears lintian E:no-copyright-file (`1955ed2`)
- **api**: add DevicePolicy=closed + IPAddressAllow=any (kills 0.3 badness) (`788426d`)
- **api**: use explicit CIDR ranges in IPAddressAllow (systemd-analyze ignores 'any') (`dedb918`)
- **api**: add IPAddressDeny=any (sets deny_all flag systemd-analyze credits) (`487ea3a`)
- **api**: suppress hadolint DL3007 (Chainguard images use rolling :latest by design) (`beedf7f`)
- **deps**: update uvicorn[standard] requirement from >=0.32 to >=0.48.0 (`345fe1b`)
