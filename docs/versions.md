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

## Helm charts

| chart        | version                                | mirrors appVersion                   |
|--------------|----------------------------------------|--------------------------------------|
| `chart-api`  | {{ config.extra.versions.chart_api }}  | api {{ config.extra.versions.api }}  |
| `chart-job`  | {{ config.extra.versions.chart_job }}  | job {{ config.extra.versions.job }}  |
| `chart-ssr`  | {{ config.extra.versions.chart_ssr }}  | ssr {{ config.extra.versions.ssr }}  |

## Documentation

| component | version                           |
|-----------|-----------------------------------|
| `docs`    | {{ config.extra.versions.docs }}  |
</content>
