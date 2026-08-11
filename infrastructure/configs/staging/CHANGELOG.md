# Changelog — staging

What has actually been applied to the `staging` environment. Unlike the other
components, this one is not a library: it is bumped only by
`.github/workflows/infra-apply.yml` after a successful `terragrunt apply`,
and tagged `configs-staging-v<version>`.

Each entry also lists the `infra` / `infra-modules-*` commits that deploy
shipped — pulled in by multicz's `upstream-notes` plugin from this
component's `depends_on` (see `multicz.toml`).

## [0.1.0] - 2026-08-11

### Features

- **infra**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)
- **infra**: bootstrap the state backend for AWS and GCP (`fc631c5`)
- **infra**: config schema for the private k8s stack, and a module matrix (`1a2db60`)

### Upstream: infra (v∅ → v0.1.0)

- - feat(infra): terragrunt landing zone with per-environment deploy gating (9d50feb)
- - fix(ci): pin every action the infra jobs use, drop action-terragrunt (fb515f9)
- - refactor(ci): per-component infra jobs, and release the infra components (e2705eb)
- - docs(versions): split infrastructure into root, modules and environments (fb9a5ab)
- - feat(infra): stamp the deployed config version onto resources (6fa50f9)
- - feat(ci): lint the terragrunt wiring, not just its formatting (f72d10d)
- - feat(infra): bootstrap the state backend for AWS and GCP (fc631c5)
- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - fix: list every terraform module in VERSION and in the docs (3ceb7d8)
- - feat(ci): release every terraform module, and waive the OpenSSL High (f14d55c)
- - fix(infra): make the terragrunt wiring depend on the modules it consumes (41b95a6)
- - fix(ci): make release-bump wait on every terraform module check (0214fd4)
- - style: keep the section separator in VERSION (15a8343)

### Upstream: infra-modules-example (v∅ → v0.1.0)

- - feat(infra): terragrunt landing zone with per-environment deploy gating (9d50feb)
- - feat(example): manage a terraform_data resource so the plan has a diff (2cd3ad8)

### Upstream: infra-modules-network-vpc-gcp (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-network-vpc-aws (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-network-subnets-gcp (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-network-subnets-aws (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-network-addresses-private-gcp (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-network-addresses-private-aws (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-network-addresses-public-gcp (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-network-addresses-public-aws (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-network-firewall-gcp (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-network-firewall-aws (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-network-routes-gcp (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-network-routes-aws (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-network-nat-gcp (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-network-nat-aws (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-dns-private-gcp (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-dns-private-aws (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-dns-public-gcp (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-dns-public-aws (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-k8s-cluster-gcp (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-k8s-cluster-aws (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-k8s-nodes-gcp (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-k8s-nodes-aws (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-vms-proxy-gcp (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)

### Upstream: infra-modules-vms-proxy-aws (v∅ → v0.1.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
