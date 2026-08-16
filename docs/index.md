---
icon: lucide/house
---

# Shomer

**Shomer** (*שׁוֹמֵר* — "guard") is a multi-tenant **OAuth2 /
OpenID Connect** authorization server. One service handles registration,
login, MFA, federated identity, OAuth2 / OIDC flows, an admin UI and a REST
API — across as many tenants as you need.

> Released under the [MIT License](https://github.com/goabonga/shomer/blob/main/LICENSE) ·
> Source on [GitHub](https://github.com/goabonga/shomer)

---

## Start where you are

| | |
|---|---|
| [**Users**](users/index.md) | What the service does, what it does not do yet, and why an environment may be unreachable on purpose. |
| [**Developers**](developers/index.md) | The workspace, running it locally, how a commit becomes a release, and what CI will ask. |
| [**DevOps**](devops/index.md) | Two environments on two clouds, how traffic leaves, how a change is deployed, and how to park one. |
| [**DevSecOps**](devsecops/index.md) | What each gate actually asserts, where it stops being useful, and [how to except one](devsecops/exceptions.md). |

## The shape of it

The repository is a [uv workspace](https://docs.astral.sh/uv/concepts/projects/workspaces/)
of independently-versioned packages, a set of Helm charts, twenty-four
Terraform modules and a Flux configuration — each with its own version, its
own changelog and its own release.

Two of those numbers mean different things and the distinction is
load-bearing: library versions say what the repository **contains**, while
`configs-<env>` versions say what is **actually deployed** in that
environment. [Versions](versions.md) lists every one and marks which is
which.

## Honestly, today

The OAuth2 / OIDC flows are **not implemented**. This repository ships the
packaging, deployment and release machinery first; the authorization logic
lands in follow-up work.

What that machinery does cover is unusually complete for a skeleton: signed
images and charts verified at admission, a private-by-default network where
egress passes a filtering proxy, plans reviewed before they are applied,
and versions that cannot drift from what is running.

<!-- Part of the 2026-07 synchronized release baseline. -->
