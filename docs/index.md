---
icon: lucide/house
---

# Shomer

**Shomer** (*שׁוֹמֵר* — "guard") is a multi-tenant **OAuth2 /
OpenID Connect** authorization server. One service handles
registration, login, MFA, federated identity, OAuth2 / OIDC flows,
an admin UI and a REST API — across as many tenants as you need.

> Released under the [MIT License](https://github.com/goabonga/shomer/blob/main/LICENSE) ·
> Source on [GitHub](https://github.com/goabonga/shomer)

---

## Components

The repository is a [uv workspace](https://docs.astral.sh/uv/concepts/projects/workspaces/)
of three independently-versioned packages:

| package         | role                          | distribution                     |
|-----------------|-------------------------------|----------------------------------|
| `shomer-api`    | FastAPI authorization server  | Docker image, Helm chart, `.deb` |
| `shomer-worker` | background polling jobs       | Docker image, Helm chart, `.deb` |
| `shomer-cli`    | operator CLI                  | wheel / sdist (PyPI)             |

Each package is released independently — its own git tag, its own
`CHANGELOG.md`, its own `debian/changelog` stanza. Cascade rules in
`multicz.toml` keep the Helm charts' `appVersion` in sync with their
matching application bumps.

## Quickstart

```bash
git clone https://github.com/goabonga/shomer.git
cd shomer

uv sync
uv run shomer-api &              # FastAPI on :8000
uv run shomer health http://127.0.0.1:8000
```

## What works today

- `GET /healthz` — liveness probe (Helm + systemd target).
- `GET /.well-known/openid-configuration` — OIDC discovery stub.
- `shomer health <url>` — operator probe via the CLI.
- `shomer-worker` — minimal polling loop with signal-based shutdown.

The OAuth2 / OIDC flows themselves are intentionally **not**
implemented in this skeleton — Shomer ships the packaging, deployment
and release machinery first, the authorization logic lands in
follow-up work.

## How to deploy

| target        | path                                   |
|---------------|----------------------------------------|
| **Docker**    | `packages/{api,worker}/Dockerfile`     |
| **Helm**      | `packages/{api,worker}/chart/`         |
| **Debian**    | `packages/{api,worker}/debian/` + systemd unit |
| **Wheel**     | `uv build -p packages/cli`             |

## Releasing

Releases are managed by [`multicz`](https://github.com/goabonga/multicz):

```bash
multicz status     # what would bump
multicz plan       # detailed plan with reasons
multicz bump       # apply versions, mirrors, writers
multicz graph      # cascade DAG (api → chart-api, etc.)
```

See `multicz.toml` for the per-component configuration.
