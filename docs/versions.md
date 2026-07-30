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

Terragrunt/Terraform under `infrastructure/`. Modules and the Terragrunt
root are libraries, released on every push to `main`.

| component                | version                                              |
|--------------------------|------------------------------------------------------|
| terragrunt root (`infra`) | {{ config.extra.versions.infra }}                    |
| `modules/example`         | {{ config.extra.versions.infra_modules_example }}    |

### Deployed environments

Unlike everything above, these are **deployed** versions: each one is
bumped only after a successful `terragrunt apply`, so the number below is
what is actually live in that environment.

| environment  | deployed version                                |
|--------------|--------------------------------------------------|
| `staging`    | {{ config.extra.versions.configs_staging }}      |
| `production` | {{ config.extra.versions.configs_production }}   |
</content>
