# Changelog

All notable changes to the Terragrunt root wiring (`services/`, the module
template, `terragrunt.sh`) are documented here. Versions follow
[Semantic Versioning](https://semver.org) and are derived from
[Conventional Commits](https://www.conventionalcommits.org) scoped to this
directory, tagged `infra-v<version>`.

## [0.8.0] - 2026-08-15

### Features

- **infra**: reserve the egress addresses, and let each cloud say how it grows (`79d1244`)

### Dependencies

- Track `infra-modules-network-addresses-public-gcp` `0.2.0`
- Track `infra-modules-network-addresses-public-aws` `0.2.0`

## [0.7.0] - 2026-08-15

### Features

- **infra**: implement the firewall, and turn off what each cloud permits by default (`034bc57`)

### Dependencies

- Track `infra-modules-network-firewall-gcp` `0.2.0`
- Track `infra-modules-network-firewall-aws` `0.2.0`

## [0.6.0] - 2026-08-15

### Features

- **infra**: implement the routes, where the workload's isolation becomes checkable (`0a6e4f5`)

### Dependencies

- Track `infra-modules-network-vpc-aws` `0.3.0`
- Track `infra-modules-network-subnets-aws` `0.3.0`
- Track `infra-modules-network-routes-gcp` `0.2.0`
- Track `infra-modules-network-routes-aws` `0.2.0`

## [0.5.0] - 2026-08-14

### Features

- **infra**: implement the subnets, where the separation is decided (`f637229`)

### Dependencies

- Track `infra-modules-network-subnets-gcp` `0.2.0`
- Track `infra-modules-network-subnets-aws` `0.2.0`

## [0.4.0] - 2026-08-13

### Features

- **infra**: implement the aws vpc, closed at creation (`86bda35`)

### Fixes

- **infra**: omit the aws-only input instead of passing it as null (`be6eec1`)

### Dependencies

- Track `infra-modules-network-vpc-aws` `0.2.0`

## [0.3.1] - 2026-08-12

### Fixes

- **infra**: plan each environment against its own config (`9f9eadb`)

## [0.3.0] - 2026-08-12

### Features

- **infra**: select the state backend from the environment config (`6c32553`)

## [0.2.0] - 2026-08-12

### Features

- **infra**: pick the provider and the cloud login from the environment config (`2cc9311`)

## [0.1.2] - 2026-08-12

### Dependencies

- Track `infra-modules-example` `0.2.0`

## [0.1.1] - 2026-08-11

### Dependencies

- Track `infra-modules-network-vpc-gcp` `0.2.0`

## [0.1.0] - 2026-08-11

### Features

- **infra**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)
- **infra**: stamp the deployed config version onto resources (`6fa50f9`)
- **ci**: lint the terragrunt wiring, not just its formatting (`f72d10d`)
- **infra**: bootstrap the state backend for AWS and GCP (`fc631c5`)
- **infra**: scaffold the private k8s stack — 12 units, 24 empty modules (`d629e2d`)
- **ci**: release every terraform module, and waive the OpenSSL High (`f14d55c`)

### Fixes

- **ci**: pin every action the infra jobs use, drop action-terragrunt (`fb515f9`)
- list every terraform module in VERSION and in the docs (`3ceb7d8`)
- **infra**: make the terragrunt wiring depend on the modules it consumes (`41b95a6`)
- **ci**: make release-bump wait on every terraform module check (`0214fd4`)

### Dependencies

- Track `infra-modules-example` `0.1.0`
- Track `infra-modules-network-vpc-gcp` `0.1.0`
- Track `infra-modules-network-vpc-aws` `0.1.0`
- Track `infra-modules-network-subnets-gcp` `0.1.0`
- Track `infra-modules-network-subnets-aws` `0.1.0`
- Track `infra-modules-network-addresses-private-gcp` `0.1.0`
- Track `infra-modules-network-addresses-private-aws` `0.1.0`
- Track `infra-modules-network-addresses-public-gcp` `0.1.0`
- Track `infra-modules-network-addresses-public-aws` `0.1.0`
- Track `infra-modules-network-firewall-gcp` `0.1.0`
- Track `infra-modules-network-firewall-aws` `0.1.0`
- Track `infra-modules-network-routes-gcp` `0.1.0`
- Track `infra-modules-network-routes-aws` `0.1.0`
- Track `infra-modules-network-nat-gcp` `0.1.0`
- Track `infra-modules-network-nat-aws` `0.1.0`
- Track `infra-modules-dns-private-gcp` `0.1.0`
- Track `infra-modules-dns-private-aws` `0.1.0`
- Track `infra-modules-dns-public-gcp` `0.1.0`
- Track `infra-modules-dns-public-aws` `0.1.0`
- Track `infra-modules-k8s-cluster-gcp` `0.1.0`
- Track `infra-modules-k8s-cluster-aws` `0.1.0`
- Track `infra-modules-k8s-nodes-gcp` `0.1.0`
- Track `infra-modules-k8s-nodes-aws` `0.1.0`
- Track `infra-modules-vms-proxy-gcp` `0.1.0`
- Track `infra-modules-vms-proxy-aws` `0.1.0`
