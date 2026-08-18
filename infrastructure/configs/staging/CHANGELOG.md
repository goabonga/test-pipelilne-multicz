# Changelog — staging

What has actually been applied to the `staging` environment. Unlike the other
components, this one is not a library: it is bumped only by
`.github/workflows/infra-apply.yml` after a successful `terragrunt apply`,
and tagged `configs-staging-v<version>`.

Each entry also lists the `infra` / `infra-modules-*` commits that deploy
shipped — pulled in by multicz's `upstream-notes` plugin from this
component's `depends_on` (see `multicz.toml`).

## [0.1.0] - 2026-08-18

### Features

- **infra**: terragrunt landing zone with per-environment deploy gating (`9d50feb`)
- **infra**: bootstrap the state backend for AWS and GCP (`fc631c5`)
- **infra**: config schema for the private k8s stack, and a module matrix (`1a2db60`)
- **infra**: select the state backend from the environment config (`6c32553`)
- **infra**: put both environments on their remote state backend (`7477792`)
- **infra**: name the example unit for what it is (`c8f4c84`)
- **infra**: implement the firewall, and turn off what each cloud permits by default (`034bc57`)
- **infra**: implement the egress proxy, where the policy stops being about routes (`00ddf6e`)
- **infra**: implement the clusters, and settle Cilium in opposite directions (`3381a38`)
- **infra**: implement the node pools, and the setting each cloud hangs egress on (`b9e6a57`)
- **infra**: implement the DNS zones, private everywhere and public only where intended (`bd81a0c`)
- **infra**: decide the proxy's private address, and untie the ordering knot (`5258c73`)
- **infra**: enable the network units (`78a9e5a`)

### Fixes

- **infra**: turn off the units whose provider is not wired yet (`c23da8f`)

### Upstream: infra (v∅ → v0.15.0)

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
- - feat(infra): pick the provider and the cloud login from the environment config (2cc9311)
- - feat(infra): select the state backend from the environment config (6c32553)
- - docs(infra): say which state needs migrating, and add the block to migrate it (58e5790)
- - fix(infra): plan each environment against its own config (9f9eadb)
- - docs(infra): explain the CI identity and what it is not (944bc76)
- - feat(infra): implement the aws vpc, closed at creation (86bda35)
- - fix(infra): omit the aws-only input instead of passing it as null (be6eec1)
- - feat(infra): implement the subnets, where the separation is decided (f637229)
- - feat(infra): implement the routes, where the workload's isolation becomes checkable (0a6e4f5)
- - feat(infra): implement the firewall, and turn off what each cloud permits by default (034bc57)
- - feat(infra): reserve the egress addresses, and let each cloud say how it grows (79d1244)
- - feat(infra): implement the NAT, and refuse the default that would undo the design (f7dbd7a)
- - feat(infra): implement the egress proxy, where the policy stops being about routes (00ddf6e)
- - feat(infra): implement the clusters, and settle Cilium in opposite directions (3381a38)
- - feat(infra): implement the node pools, and the setting each cloud hangs egress on (b9e6a57)
- - feat(infra): implement the DNS zones, private everywhere and public only where intended (bd81a0c)
- - feat(infra): decide the proxy's private address, and untie the ordering knot (5258c73)
- - … and 2 more

### Upstream: infra-modules-example (v∅ → v0.2.0)

- - feat(infra): terragrunt landing zone with per-environment deploy gating (9d50feb)
- - feat(example): manage a terraform_data resource so the plan has a diff (2cd3ad8)
- - feat(example): carry the config version into the resource identity (155e17a)

### Upstream: infra-modules-network-vpc-gcp (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(network-vpc-gcp): implement the VPC, without a way out by default (da38756)

### Upstream: infra-modules-network-vpc-aws (v∅ → v0.3.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the aws vpc, closed at creation (86bda35)
- - feat(infra): implement the routes, where the workload's isolation becomes checkable (0a6e4f5)

### Upstream: infra-modules-network-subnets-gcp (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the subnets, where the separation is decided (f637229)

### Upstream: infra-modules-network-subnets-aws (v∅ → v0.3.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the subnets, where the separation is decided (f637229)
- - feat(infra): implement the routes, where the workload's isolation becomes checkable (0a6e4f5)

### Upstream: infra-modules-network-addresses-private-gcp (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): decide the proxy's private address, and untie the ordering knot (5258c73)

### Upstream: infra-modules-network-addresses-private-aws (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): decide the proxy's private address, and untie the ordering knot (5258c73)

### Upstream: infra-modules-network-addresses-public-gcp (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): reserve the egress addresses, and let each cloud say how it grows (79d1244)

### Upstream: infra-modules-network-addresses-public-aws (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): reserve the egress addresses, and let each cloud say how it grows (79d1244)

### Upstream: infra-modules-network-firewall-gcp (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the firewall, and turn off what each cloud permits by default (034bc57)

### Upstream: infra-modules-network-firewall-aws (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the firewall, and turn off what each cloud permits by default (034bc57)

### Upstream: infra-modules-network-routes-gcp (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the routes, where the workload's isolation becomes checkable (0a6e4f5)

### Upstream: infra-modules-network-routes-aws (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the routes, where the workload's isolation becomes checkable (0a6e4f5)

### Upstream: infra-modules-network-nat-gcp (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the NAT, and refuse the default that would undo the design (f7dbd7a)

### Upstream: infra-modules-network-nat-aws (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the NAT, and refuse the default that would undo the design (f7dbd7a)

### Upstream: infra-modules-dns-private-gcp (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the DNS zones, private everywhere and public only where intended (bd81a0c)

### Upstream: infra-modules-dns-private-aws (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the DNS zones, private everywhere and public only where intended (bd81a0c)

### Upstream: infra-modules-dns-public-gcp (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the DNS zones, private everywhere and public only where intended (bd81a0c)

### Upstream: infra-modules-dns-public-aws (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the DNS zones, private everywhere and public only where intended (bd81a0c)

### Upstream: infra-modules-k8s-cluster-gcp (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the clusters, and settle Cilium in opposite directions (3381a38)

### Upstream: infra-modules-k8s-cluster-aws (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the clusters, and settle Cilium in opposite directions (3381a38)

### Upstream: infra-modules-k8s-nodes-gcp (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the node pools, and the setting each cloud hangs egress on (b9e6a57)

### Upstream: infra-modules-k8s-nodes-aws (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the node pools, and the setting each cloud hangs egress on (b9e6a57)

### Upstream: infra-modules-vms-proxy-gcp (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the egress proxy, where the policy stops being about routes (00ddf6e)

### Upstream: infra-modules-vms-proxy-aws (v∅ → v0.2.0)

- - feat(infra): scaffold the private k8s stack — 12 units, 24 empty modules (d629e2d)
- - feat(infra): implement the egress proxy, where the policy stops being about routes (00ddf6e)
