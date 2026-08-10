# Changelog

All notable changes to the Terragrunt root wiring (`services/`, the module
template, `terragrunt.sh`) are documented here. Versions follow
[Semantic Versioning](https://semver.org) and are derived from
[Conventional Commits](https://www.conventionalcommits.org) scoped to this
directory, tagged `infra-v<version>`.

## [0.1.0] - 2026-08-10

### Features

- **infra**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)
- **infra**: stamp the deployed config version onto resources (`6fa50f9`)
- **ci**: lint the terragrunt wiring, not just its formatting (`f72d10d`)
- **infra**: bootstrap the state backend for AWS and GCP (`fc631c5`)

### Fixes

- **ci**: pin every action the infra jobs use, drop action-terragrunt (`fb515f9`)
