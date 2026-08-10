# Changelog — staging

What has actually been applied to the `staging` environment. Unlike the other
components, this one is not a library: it is bumped only by
`.github/workflows/infra-apply.yml` after a successful `terragrunt apply`,
and tagged `configs-staging-v<version>`.

Each entry also lists the `infra` / `infra-modules-*` commits that deploy
shipped — pulled in by multicz's `upstream-notes` plugin from this
component's `depends_on` (see `multicz.toml`).

## [0.1.0] - 2026-08-10

### Features

- **infra**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)
- **infra**: bootstrap the state backend for AWS and GCP (`fc631c5`)

### Upstream: infra (v∅ → v0.1.0)

- - feat(infra): terragrunt landing zone with per-environment deploy gating (9d50feb)
- - fix(ci): pin every action the infra jobs use, drop action-terragrunt (fb515f9)
- - refactor(ci): per-component infra jobs, and release the infra components (e2705eb)
- - docs(versions): split infrastructure into root, modules and environments (fb9a5ab)
- - feat(infra): stamp the deployed config version onto resources (6fa50f9)
- - feat(ci): lint the terragrunt wiring, not just its formatting (f72d10d)
- - feat(infra): bootstrap the state backend for AWS and GCP (fc631c5)

### Upstream: infra-modules-example (v∅ → v0.1.0)

- - feat(infra): terragrunt landing zone with per-environment deploy gating (9d50feb)
- - feat(example): manage a terraform_data resource so the plan has a diff (2cd3ad8)
