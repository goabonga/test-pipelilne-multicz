# Security Policy

## Supported versions

Only the latest minor release line of each Shomer component receives
security fixes. Once a new minor lands, the previous one is supported
for one additional patch cycle, then sunsetted.

## Reporting a vulnerability

Shomer is an authorization server: vulnerabilities here have outsized
blast radius. **Do not open a public GitHub issue.**

Email **goabonga@pm.me** with:

- the affected component (api, worker, cli) and version
- a reproduction recipe (smallest config / request / token sequence)
- your assessment of the impact (scope escalation, token leak, …)

You will receive an acknowledgement within 72 hours. We aim to
publish a fix within 14 days for high-severity issues, 30 days
otherwise. Coordinated disclosure is welcome — please give us the
two-week window before public discussion.

## Scope

In scope:

- the `shomer-api` HTTP surface (OAuth2/OIDC endpoints, admin API)
- the `shomer-worker` background jobs and their input data
- the `shomer-cli` (credential handling, host verification)
- the published Docker images and `.deb` packages
- the bundled Helm chart defaults

Out of scope: third-party dependencies (report upstream), denial of
service via untuned resource limits, social engineering of
maintainers.
