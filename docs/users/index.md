---
icon: lucide/user
---

# For users

What Shomer does for the person using it, and what it does not do yet.

## What it is

An **OAuth2 / OpenID Connect** authorization server with multi-tenant
support. One deployment serves registration, login, MFA, federated
identity and the flows that let other applications delegate authentication
to it — across as many tenants as you need.

## What works today

Be told plainly rather than find out: **the OAuth2 / OIDC flows are not
implemented yet.** This repository ships the packaging, deployment and
release machinery first; the authorization logic lands in follow-up work.

What responds today:

| endpoint | what it answers |
|---|---|
| `GET /healthz` | whether the service is alive |
| `GET /.well-known/openid-configuration` | an OIDC discovery document — a stub |

So a client can discover the server and a load balancer can decide it is
healthy. A client cannot yet complete a login.

## Reaching it

Only **production** is reachable from the internet, and only through the
load balancer. Staging is internal by design — if you cannot reach it from
outside, that is the intended behaviour rather than a fault.

The Kubernetes API is private in every environment, including production.
That is a separate front door from the one serving the application, and it
is not open to anyone.

## Checking a deployment yourself

The operator CLI ships as a wheel and a `.deb`:

```bash
shomer health https://<the-deployment>
```

It reports what `/healthz` says, which is the same question the load
balancer asks before sending anyone to an instance.

## When something is unreachable

Three causes account for most of it, and they look identical from outside:

- **The environment is internal.** Staging is not published. Nothing is
  broken.
- **The name is not delegated.** A public DNS zone that the registrar does
  not point at is authoritative for nothing: every record in it is correct
  and unreachable, which looks exactly like a propagation delay for as
  long as you are willing to wait.
- **The environment is parked.** Expensive parts of an environment can be
  torn down deliberately to stop them costing money while idle. See
  [teardown](../devops/teardown.md); bringing them back is an ordinary
  deployment.
