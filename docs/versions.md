---
icon: lucide/tags
---

# Versions

The currently-released version of every Shomer component.

## Applications

| component      | version                              | distribution              |
|----------------|--------------------------------------|---------------------------|
| `shomer-api`   | {{ config.extra.versions.api }}      | docker / helm / `.deb`    |
| `shomer-job`   | {{ config.extra.versions.job }}      | docker / helm / `.deb`    |
| `shomer-ssr`   | {{ config.extra.versions.ssr }}      | docker / helm / `.deb`    |
| `shomer-cli`   | {{ config.extra.versions.cli }}      | wheel / sdist (PyPI)      |
| `shomer-web`   | {{ config.extra.versions.web }}      | bundled into `shomer-ssr` |
| `shomer-app`   | {{ config.extra.versions.app }}      | APK / IPA (GitHub release)|

## Libraries

Consumed by the applications above; not shipped on their own.

| component           | version                                      | consumed by            |
|---------------------|----------------------------------------------|------------------------|
| `shomer-database`   | {{ config.extra.versions.database }}         | api, job, migrations   |
| `shomer-migrations` | {{ config.extra.versions.migrations }}       | migration image        |
| `@shomer/lib`       | {{ config.extra.versions.lib }}              | web, app               |

## Helm charts

| chart        | version                                | mirrors appVersion                   |
|--------------|----------------------------------------|--------------------------------------|
| `chart-api`  | {{ config.extra.versions.chart_api }}  | api {{ config.extra.versions.api }}  |
| `chart-job`  | {{ config.extra.versions.chart_job }}  | job {{ config.extra.versions.job }}  |
| `chart-ssr`  | {{ config.extra.versions.chart_ssr }}  | ssr {{ config.extra.versions.ssr }}  |
| `chart-migrations` | {{ config.extra.versions.chart_migrations }} | migrations {{ config.extra.versions.migrations }} |

## Documentation

| component | version                           |
|-----------|-----------------------------------|
| `docs`    | {{ config.extra.versions.docs }}  |

## Infrastructure

Terragrunt/Terraform under `infrastructure/`. Three kinds of version, and
the difference between them is the point: the first two are libraries,
released on every push to `main`; the third is deployed state.

### Terragrunt root

The shared wiring every unit includes — `root.hcl`, `services/**`, the
module template and the helper scripts.

| component | version                            |
|-----------|-------------------------------------|
| `infra`   | {{ config.extra.versions.infra }}   |

### Terraform modules

Consumed by the units under `services/`. Each is versioned, changelogged
and tagged on its own; the version is recorded in the module's `README.md`.

| module            | version                                           |
|-------------------|---------------------------------------------------|
| `example`         | {{ config.extra.versions.infra_modules_example }} |

### Configurations (deployed environments)

Unlike everything above, these are **deployed** versions. Each is bumped
only after a successful `terragrunt apply`, so the number below is what is
actually live in that environment — not what the repository contains.

| environment  | deployed version                                |
|--------------|--------------------------------------------------|
| `staging`    | {{ config.extra.versions.configs_staging }}      |
| `production` | {{ config.extra.versions.configs_production }}   |
