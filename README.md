<h1 align="center">
  <img src="docs/shomer.svg" alt="Shomer" width="120" /><br/>
  Shomer
</h1>

<p align="center">
  <em>Multi-tenant OAuth2 / OpenID Connect authorization server.</em>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT"/></a>
  <img src="https://img.shields.io/badge/python-3.11%2B-blue.svg" alt="Python 3.11+"/>
  <img src="https://img.shields.io/badge/FastAPI-async-009688.svg" alt="FastAPI"/>
</p>

---

A uv workspace whose parts are versioned, tagged and released
independently by [`multicz`](https://github.com/goabonga/multicz) — 21
components in all, covering the application, its charts, its
infrastructure and its GitOps state.

## Packages

| package             | role                                            | distribution                     |
|---------------------|-------------------------------------------------|----------------------------------|
| `shomer-api`        | FastAPI authorization server                     | Docker image, Helm chart, `.deb` |
| `shomer-job`        | background jobs (token cleanup, audit replication) | Docker image, Helm chart, `.deb` |
| `shomer-ssr`        | Jinja-rendered login / account UI                | Docker image, Helm chart, `.deb` |
| `shomer-migrations` | Alembic revisions + runner                       | Docker image, Helm chart         |
| `shomer-database`   | SQLAlchemy models and connector                  | wheel, consumed by the services  |
| `shomer-cli`        | operator CLI                                     | wheel / sdist (PyPI), `.deb`     |
| `shomer-web`        | React islands / CSS / Jinja templates for `ssr`  | built into `shomer-ssr`          |
| `@shomer/lib`       | shared TypeScript types, validation, API helpers | consumed by `web` and `app`      |
| `@shomer/app`       | React Native app (iOS + Android)                 | store artifacts                  |

The four Helm charts live beside the service they deploy
(`packages/<name>/chart/`) and carry their own version stream.

## Quickstart

```bash
make install                     # sync the workspace (all packages + dev/doc groups)
uv run shomer-api &              # FastAPI on :8000
uv run shomer health http://127.0.0.1:8000
```

The full stack — the same charts CI deploys, images built from the
working tree — runs on a local kind cluster:

```bash
make kind-up                     # build, load, helm install api/job/ssr/migrations + postgres
make kind-forward                # api on :8000, ssr on :8080
make kind-down
```

`make help` lists every target.

## Layout

```
packages/
├── api/          Python + Dockerfile + chart/ + debian/
├── job/          Python + Dockerfile + chart/ + debian/
├── ssr/          Python + Dockerfile + chart/ + debian/  (assets built by web/)
├── cli/          Python + debian/                        (wheel + .deb, no chart)
├── web/          Node (TS / CSS / templates)             → built into ssr/
├── lib/          Node (shared TS)                        → consumed by web/ and app/
├── app/          React Native (iOS + Android)
└── bdd/
    ├── database/     SQLAlchemy models + connector
    └── migrations/   Alembic revisions + Dockerfile + chart/

infrastructure/   Terragrunt: root.hcl, modules/, services/, configs/<env>/
gitops/           Flux: clusters/, infrastructure/, apps/{base,staging,production}/
scripts/          terragrunt.sh, kind-dev.sh, gitops-pin.sh, module scaffolding
docs/             zensical site
```

## Releases

Every component has its own tag, its own `CHANGELOG.md` and — where it
applies — its own `debian/changelog` stanza. Cascades flow along the
dependency graph declared in [`multicz.toml`](multicz.toml): `api` /
`job` / `ssr` versions mirror into the matching `Chart.yaml#appVersion`,
a `web` build cascades a patch onto `ssr`, and any bump cascades onto
`docs` so the published versions page stays current.

```bash
make release-status              # what is pending
make release-plan                # the full plan, with reasons
make release-graph               # the cascade DAG
```

Library components release on every push to `main` that touches them.
The components that describe **deployed state** do not — see below.

## Deploying

`configs-<env>` and `gitops-<env>` are not libraries: they record what is
actually applied in an environment, so releasing them without deploying
would be a lie. They are excluded from the automatic release and move
only through a reviewed deploy.

Both follow the same shape:

```
ci finishes on main
  → the planner resets the gate branch onto main
  → bumps the component on <gate>-<version>
  → plans against that version
  → drift  → PR <gate>-<version> → <gate>, plan attached as an artifact
  → merge  → the applier waits on the environment's reviewers
           → applies, rebases onto main, tags and releases, atomically
```

|                    | infrastructure                | GitOps                          |
|--------------------|-------------------------------|---------------------------------|
| planner            | `infra-plan.yml`              | `promote-production.yml`        |
| gate branch        | `deploy/<env>`                | `gitops/production`             |
| applier            | `infra-apply.yml`             | `gitops-apply.yml`              |
| what "apply" means | `terragrunt apply`            | Flux reconciles the merged pins |

Two confirmations, deliberately. Merging the PR says *this diff and this
plan are right*; approving the GitHub Environment says *apply it now*.
The gate branches require no PR approval of their own — the environment
reviewers are the authorisation, and they are asked at the moment the
change takes effect rather than hours earlier.

`config.yaml`'s `version:` is stamped onto every resource as the
`config-version` tag, so the plan is always computed against the version
that will actually be applied. Staging deploys continuously; production
asks.

## Infrastructure

Terragrunt over local Terraform modules, one config per environment. No
cloud provider is wired yet — modules are tested offline with
`mock_provider`, so none of these need credentials:

```bash
make infra-lint                  # hcl validate + inputs/variables cross-check
make infra-test                  # terraform test (M=<name> for one module)
make infra-checkov               # static analysis
make infra-plan ENV=staging      # plan one environment
make infra-new-module NAME=<x>   # scaffold + register a module
```

## License

[MIT](LICENSE).
