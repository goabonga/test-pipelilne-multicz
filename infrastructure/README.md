# Infrastructure

Terragrunt/Terraform for shomer, laid out so that **modules are libraries**
and **environment configs are deployed state** — two different things, with
two different release rules.

```
infrastructure/
├── root.hcl                  # Terragrunt root: config lookup, provider + backend wiring
├── modules/                  # Terraform modules, each versioned independently
│   ├── _template/            # scaffold to copy — not a module, not released
│   └── example/              # reference module (infra-modules-example)
│       ├── README.md         # holds the version + the terraform-docs block
│       └── .terraform-docs.yml
├── services/                 # Terragrunt units — one directory per unit
│   └── example/
└── configs/
    ├── staging/              # config.yaml (version lives in it) + CHANGELOG.md
    └── production/
```

Shell helpers and the module scaffolder live in the repo-wide
[`scripts/`](../scripts): `terragrunt.sh`, `new-terraform-module.sh`.

## How traffic leaves

The one question this layout exists to make answerable, and the answer is
spread over four units on purpose — each closes a different half, and any
one of them alone can be undone by a single line elsewhere.

```
workload subnet          no default route, no NAT, no public addresses
      │
      │  only permitted destination: the proxy, on 3128
      ▼
egress proxy (Squid)     deny-by-default allow-list of destinations
      │
      ▼
NAT                      translates for the proxy subnet ONLY
      │
      ▼
reserved egress IPs      what external services allow-list
```

- **`network/routes`** removes the path. The workload has no `0.0.0.0/0` at
  all until the proxy exists, and never one that reaches a gateway.
- **`network/firewall`** removes the permission. A route is a path and a
  rule is an authorisation; closing only one leaves the other as the single
  point of failure.
- **`vms/proxy`** decides what may be reached. Without an allow-list the
  fleet is a router with extra steps — it satisfies "traffic leaves through
  one place" while giving up the reason that was worth arranging.
- **`network/nat`** translates for the egress subnets only. Its default is
  *every* subnet, which would hand the workload a way out that passes
  neither of the two above and works perfectly.

Each cloud is open by default in its own way, which is why the firewall
unit exists rather than being folded into routing: GCP's implied rules
**allow all egress**, and an AWS security group declared without an egress
block is given allow-all outbound by the provider. On both, "not configured
yet" is an open state that looks exactly like a closed one.

Pod-to-pod is a different layer and lives in [`../gitops`](../gitops):
these modules control node-to-world, the NetworkPolicies control
pod-to-pod, and neither substitutes for the other.

## What is not wired yet

Four values the environment configs carry as `TODO`, all for the same
reason: the apply identity deliberately holds no IAM or KMS rights, so that
the apply path has no route to privilege escalation a plan reviewer would
not see.

| Config key | What it needs |
|---|---|
| `vms.proxy.image_id` | a Debian AMI in the environment's region |
| `k8s.cluster.cluster_role_arn` | the EKS control plane role |
| `k8s.nodes.node_role_arn` | the node role |
| `k8s.cluster` KMS key | envelope encryption for Kubernetes secrets |

Every unit is `enabled: false` except `example`. A unit turns on when its
module declares resources **and** the values above exist — implementing a
module is not enough, and enabling one early fails the whole environment's
plan rather than just itself.

## Local usage

```bash
source scripts/terragrunt.sh    # sourced, not executed — it defines shell functions
switch_env staging              # selects configs/<env>/config.yaml
plan  ./services/example
apply ./services/example
```

Paths are resolved against `infrastructure/`, not the current directory, so
these work from anywhere in the repo. `switch_env` with no argument lists
the environments it found.

Non-interactive equivalents, which are what CI runs:

```bash
make infra-fmt-check                  # terraform fmt + terragrunt hcl format, non-mutating
make infra-lint                       # hcl validate + inputs/variables cross-check
make infra-test                       # terraform test in every module with a tests/ dir
make infra-docs                       # regenerate every module README with terraform-docs
make infra-docs-check                 # verify those READMEs are up to date
make infra-plan ENV=production        # plan one environment
make infra-new-module NAME=<name>     # scaffold + register a module
make infra-bootstrap CLOUD=aws|gcp    # create the state bucket (once, by hand)
make infra-oidc CLOUD=aws|gcp         # create the CI identity + set the GitHub variables
make infra-clean                      # drop .terragrunt-cache / lockfiles / generated *.tf
```

## Validating without an environment

`make infra-lint` answers "would a plan get off the ground" without
credentials, a backend or a cloud — the module source is a local path, so
nothing has to be reachable.

Two passes. `terragrunt hcl validate` parses the whole tree and resolves
every reference, catching a typo in `root.hcl` or a broken include. Then,
per environment, `hcl validate --inputs --strict` cross-checks each unit's
`inputs` against the module's declared variables.

That second one is the one that earns its place. Verified by breaking it
both ways rather than trusting the happy path:

| introduced | result |
| --- | --- |
| a required input removed | `ERROR The following required inputs are missing` — exit 1 |
| an input the module does not declare | warning only, until `--strict` makes it exit 1 |

Both are bugs that would otherwise surface at plan time, against a real
provider — which is exactly where you least want to find them.

It has since caught the mistake it was built for, twice: an input added to
the AWS implementation of a unit and not the GCP one, where a ternary
yielding `null` still passes the key. Strict mode judges the key, not its
value, and it is right to — a module that does not declare an input cannot
be relying on it.

## Turning a unit off

Use Terragrunt's `exclude` block, driven by a flag in the environment
config — not `source = null`:

```hcl
exclude {
  if      = !local.config.services.example.enabled
  actions = ["all"]
}
```

Terragrunt drops the unit from the run graph before evaluating it and
reports it as `Excluded` in the run summary, instead of a unit that
silently does nothing. Every unit should expose the toggle this way.

## Versioning and release

Three kinds of component, all declared in the repo-root
[`multicz.toml`](../multicz.toml):

| Component | What it is | When it releases |
| --- | --- | --- |
| `infra` | the Terragrunt root wiring, `services/**`, the template, the two helper scripts | immediately, on push to `main` |
| `infra-modules-<name>` | one Terraform module | immediately, on push to `main` |
| `configs-<env>` | what is **actually applied** in that environment | only after a successful `terragrunt apply` |

`release-bump` in `ci.yml` filters out every component whose name starts
with `configs-`; `infra-apply.yml` is the only thing that bumps them.
Renaming that prefix breaks the deploy gate.

Nothing under `modules/` or `configs/` carries a `VERSION` file — the
version is recorded inside the artefact it describes:

| Component | Where its version lives |
| --- | --- |
| `infra` | `VERSION` (plain file — it describes no single artefact) |
| `infra-modules-<name>` | `modules/<name>/README.md`, `**Version:** x.y.z` |
| `configs-<env>` | `configs/<env>/config.yaml`, `version:` key |

For a module a `post_bump` hook re-runs terraform-docs right after the
rewrite — see [`modules/README.md`](modules/README.md). For an environment
it means the file that describes the environment also states which version
of it is deployed, and terragrunt exposes it as `local.config.version`,
usable as a resource tag once a provider is wired.

Each `configs-<env>` lists what it deploys in `depends_on`, so multicz's
`upstream-notes` plugin pulls the `infra` / `infra-modules-*` commits that
deploy shipped into the environment's changelog and release notes.
`new-terraform-module.sh` maintains those lists.

Every version is also published on the docs site: each component writes
into `zensical.toml`'s `[project.extra.versions]` and sits in `docs`'
`depends_on`, so [versions.md](../docs/versions.md) ships current numbers —
including, for `configs-<env>`, the version actually live in that
environment. `new-terraform-module.sh` wires a new module into all four
places (component, `depends_on`, `zensical.toml` key, versions table); half
of that done by hand fails silently, the module releases fine and just
stops appearing anywhere.

## Deploy flow

```
push to main
   └─ ci.yml release-bump — bumps infra / infra-modules-*, never configs-*
        └─ dispatches infra-plan.yml
             └─ discover-envs — asks multicz which configs-<env> are pending
                  └─ plan, per pending environment
                       └─ diff?  →  PR from main into deploy/<env>, summary only
                            └─ approve + merge
                                 └─ infra-apply.yml — terragrunt apply
                                      └─ bump configs-<env>, tag, push, ff main
```

`infra-plan.yml` has **no `paths:` filter**: multicz decides. An environment
is planned when its `configs-<env>` component has undeployed changes, which
is the same question the workflow exists to answer. A module or a
`services/**` change cascades onto every environment through `depends_on`
and plans all of them; editing one environment's `config.yaml` plans only
that one.

That pending state is also the ledger: `release-bump` never bumps
`configs-*`, so an environment stays pending — and keeps being planned —
until an apply clears it.

One-time setup per environment:

1. create a `deploy/<env>` branch from `main`;
2. protect it — required approving review. **The branch protection is the
   gate.** Anything able to push to `deploy/<env>` applies to that
   environment;
3. create the `<env>` and `<env>-plan` GitHub Environments, and protect
   `<env>` with required reviewers as a second gate;
4. once a provider is wired, give each its own credentials — `<env>-plan`
   read-only, `<env>` write. A genuinely separate identity, not the same
   credentials behind a different name.
