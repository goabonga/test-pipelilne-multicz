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

Terragrunt/Terraform under `infrastructure/`. The difference between the
families below is the point: everything up to the bootstraps is a library,
released on every push to `main` that touches it; the configurations at the
end are deployed state, released only after a real apply.

### Terragrunt root

The shared wiring every unit includes — `root.hcl`, `services/**`, the
module template and the helper scripts.

| component | version                            |
|-----------|-------------------------------------|
| `infra`   | {{ config.extra.versions.infra }}   |

### Terraform modules

Consumed by the units under `services/`. Each is versioned, changelogged
and tagged on its own; the version is recorded in the module's `README.md`.

| module | version |
|--------|---------|
| `dns-private-aws` | {{ config.extra.versions.infra_modules_dns_private_aws }} |
| `dns-private-gcp` | {{ config.extra.versions.infra_modules_dns_private_gcp }} |
| `dns-public-aws` | {{ config.extra.versions.infra_modules_dns_public_aws }} |
| `dns-public-gcp` | {{ config.extra.versions.infra_modules_dns_public_gcp }} |
| `example` | {{ config.extra.versions.infra_modules_example }} |
| `k8s-cluster-aws` | {{ config.extra.versions.infra_modules_k8s_cluster_aws }} |
| `k8s-cluster-gcp` | {{ config.extra.versions.infra_modules_k8s_cluster_gcp }} |
| `k8s-nodes-aws` | {{ config.extra.versions.infra_modules_k8s_nodes_aws }} |
| `k8s-nodes-gcp` | {{ config.extra.versions.infra_modules_k8s_nodes_gcp }} |
| `network-addresses-private-aws` | {{ config.extra.versions.infra_modules_network_addresses_private_aws }} |
| `network-addresses-private-gcp` | {{ config.extra.versions.infra_modules_network_addresses_private_gcp }} |
| `network-addresses-public-aws` | {{ config.extra.versions.infra_modules_network_addresses_public_aws }} |
| `network-addresses-public-gcp` | {{ config.extra.versions.infra_modules_network_addresses_public_gcp }} |
| `network-firewall-aws` | {{ config.extra.versions.infra_modules_network_firewall_aws }} |
| `network-firewall-gcp` | {{ config.extra.versions.infra_modules_network_firewall_gcp }} |
| `network-nat-aws` | {{ config.extra.versions.infra_modules_network_nat_aws }} |
| `network-nat-gcp` | {{ config.extra.versions.infra_modules_network_nat_gcp }} |
| `network-routes-aws` | {{ config.extra.versions.infra_modules_network_routes_aws }} |
| `network-routes-gcp` | {{ config.extra.versions.infra_modules_network_routes_gcp }} |
| `network-subnets-aws` | {{ config.extra.versions.infra_modules_network_subnets_aws }} |
| `network-subnets-gcp` | {{ config.extra.versions.infra_modules_network_subnets_gcp }} |
| `network-vpc-aws` | {{ config.extra.versions.infra_modules_network_vpc_aws }} |
| `network-vpc-gcp` | {{ config.extra.versions.infra_modules_network_vpc_gcp }} |
| `vms-proxy-aws` | {{ config.extra.versions.infra_modules_vms_proxy_aws }} |
| `vms-proxy-gcp` | {{ config.extra.versions.infra_modules_vms_proxy_gcp }} |

### State backend bootstraps

The roots that create the bucket every other unit stores its state in.
Applied by hand, once, with local state — Terraform cannot keep its state
in a bucket Terraform has not created yet. They are versioned like the
modules above because someone has to be able to say which revision created
the bucket their state lives in; the number does **not** mean the bucket
has been re-created since.

| bootstrap        | version                                        |
|------------------|------------------------------------------------|
| `bootstrap/aws`  | {{ config.extra.versions.infra_bootstrap_aws }} |
| `bootstrap/gcp`  | {{ config.extra.versions.infra_bootstrap_gcp }} |

### Flux wiring

The shared pieces both clusters include — HelmRelease templates, cluster
entrypoints, the chart repository. A library, like the Terragrunt root.

| component | version                              |
|-----------|---------------------------------------|
| `gitops`  | {{ config.extra.versions.gitops }}    |

### Configurations (deployed environments)

Unlike everything above, these are **deployed** versions. Each is bumped
only after a successful `terragrunt apply`, so the number below is what is
actually live in that environment — not what the repository contains.

| environment  | deployed version                                |
|--------------|--------------------------------------------------|
| `staging`    | {{ config.extra.versions.configs_staging }}      |
| `production` | {{ config.extra.versions.configs_production }}   |

And what Flux has actually been asked to reconcile — the chart pins, moved
by a bot for staging and by a reviewed PR for production.

| environment  | promoted pins                                     |
|--------------|---------------------------------------------------|
| `staging`    | {{ config.extra.versions.gitops_staging }}        |
| `production` | {{ config.extra.versions.gitops_production }}     |
