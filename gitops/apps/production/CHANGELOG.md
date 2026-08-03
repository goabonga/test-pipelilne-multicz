# Changelog — production

What has actually been promoted to `production`. Bumped by the workflow that
moves the pins, and tagged `gitops-production-v<version>`.

Each entry lists the `chart-*` commits the promotion carries, pulled in by
multicz's `upstream-notes` plugin from this component's `depends_on`.

The version records that the pins were **promoted**, not that the cluster
converged — Flux applies asynchronously and nothing here waits on it.

## [0.1.1] - 2026-08-03

_No notable changes._

## [0.1.0] - 2026-07-31

### Features

- **gitops**: flux layout with pinned staging and production (`799dccf`)

### Upstream: chart-api (v∅ → v1.4.0)

- - feat(api): add Dockerfile and helm chart (c215f8e)
- - refactor(chart): use .Chart.Name instead of hardcoded shomer-* in templates (93c047d)
- - fix(chart-api): harden Deployment (securityContext, NetworkPolicy, RO root, no SA token) (26c049a)
- - feat(chart-api): set Chart.yaml icon (ArtifactHub + Lens render the shield) (f1501f6)
- - refactor!: rename components (worker->job, web->ssr, web-frontend->web) (ba4d5b8)
- - fix(chart-api): describe what the chart actually deploys (cb73a50)
- - chore: revert dangling chore(release) api-v0.2.1 / chart-api-v1.0.4 (c8ccb97)
- - feat: cut a synchronized release baseline across all components (eb7f6d3)
- - feat(chart-api): declare home, sources and maintainers (29cf326)
- - feat(ci): sign charts and .deb, verify every signature, pin composite actions (cedacec)
- - feat(chart-api,chart-job,chart-ssr,chart-migrations): make the Sigstore endpoints configurable (5d9cffb)

### Upstream: chart-job (v∅ → v1.3.0)

- - refactor!: rename components (worker->job, web->ssr, web-frontend->web) (ba4d5b8)
- - fix(chart-job): describe what the chart actually deploys (d2aeb4d)
- - fix(chart-job): raise job memory limit to 256Mi (c1ac65c)
- - feat(chart-job): declare home, sources and maintainers (048b482)
- - feat(ci): sign charts and .deb, verify every signature, pin composite actions (cedacec)
- - feat(chart-api,chart-job,chart-ssr,chart-migrations): make the Sigstore endpoints configurable (5d9cffb)

### Upstream: chart-ssr (v∅ → v1.4.0)

- - refactor!: rename components (worker->job, web->ssr, web-frontend->web) (ba4d5b8)
- - chore(chart-ssr): tighten the Chart.yaml description (3d00d75)
- - fix(chart-ssr): collapse the line-wrapped description into one line (681ce23)
- - feat: cut a synchronized release baseline across all components (eb7f6d3)
- - feat(chart-ssr): declare home, sources and maintainers (75333c2)
- - feat(ci): sign charts and .deb, verify every signature, pin composite actions (cedacec)
- - feat(chart-api,chart-job,chart-ssr,chart-migrations): make the Sigstore endpoints configurable (5d9cffb)

### Upstream: chart-migrations (v∅ → v0.5.0)

- - feat(migrations): add shomer-migrations package (dfa8e59)
- - fix(chart-migrations): add a baseline NetworkPolicy for the migration pod (a45f2ad)
- - feat: cut a synchronized release baseline across all components (eb7f6d3)
- - feat(chart-migrations): declare home, sources and maintainers (66c1a46)
- - feat(ci): sign charts and .deb, verify every signature, pin composite actions (cedacec)
- - feat(chart-api,chart-job,chart-ssr,chart-migrations): make the Sigstore endpoints configurable (5d9cffb)
