# GitOps

Flux reconciles the two environments from this directory. Nothing here is
applied by CI — Flux pulls, which is why no workflow in this repository
holds a kubeconfig.

```
gitops/
├── clusters/{staging,production}/   # what `flux bootstrap` points at
├── infrastructure/                   # HelmRepository (OCI) + namespace
└── apps/
    ├── base/                         # one HelmRelease per component
    ├── staging/                      # version pins, moved by a bot
    └── production/                   # version pins, moved by a reviewed PR
```

## Both environments are pinned

Staging could have used a semver range and let Flux resolve it on every
interval — no commits at all. It does not, on purpose: with a range, git
tells you `>=0.0.0` and nothing more, so "what was running last Tuesday"
can only be answered by asking the cluster. Pinning keeps git the record:
`git checkout <sha>` reconstructs the exact state and `git revert` is a
rollback.

Continuous updates still happen. They are mediated by a commit rather than
by range resolution, which costs one CI round-trip instead of one Flux
interval — irrelevant for staging, and worth the audit trail.

## The only difference between the two is who moves the pin

| | staging | production |
| --- | --- | --- |
| chart version | pinned | pinned |
| who moves it | a workflow, committed straight to `main` | a reviewed PR, gated by the `production` GitHub Environment |
| multicz component | `gitops-staging` | `gitops-production` |

Keeping the axis to "who moves the pin" — rather than "range versus pin" —
means the two environments are the same shape and a reviewer only has to
check one thing.

## Signature verification

Every `HelmRelease` verifies the chart's cosign signature before install,
pinning both the OIDC issuer and the workflow identity. Pinning the issuer
alone would accept a signature from any GitHub workflow in any repository.

That is the fourth layer on the same chain: charts are signed at publish
time, verified immediately in CI, verified again here before Flux installs
anything, and then enforced in-cluster by the Kyverno policy the charts
ship (`imageVerification.enabled`). This one is the layer that stops an
unsigned chart from being installed at all.

## The promotion workflows

```
un chart est releasé sur main
 └─ promote-staging (job de ci.yml)
      pins staging <- versions releasées, commit direct sur main
      bump gitops-staging

promote-production.yml  (workflow_dispatch, environment: production)
 └─ pins production <- pins staging          ← gate 1 : required reviewers
      ouvre la PR promote/production
         └─ merge                             ← gate 2 : revue de la PR
              └─ release-gitops-production (job de ci.yml)
                   bump gitops-production
```

Production promotion is a **copy of the staging pins**, never a fresh
version lookup. Production can therefore only ever run something staging
ran first — the ordering is a property of the mechanism rather than a rule
people have to remember.

Neither workflow touches a cluster. The Environment gates the *promotion*;
Flux does the deployment. A job running `helm upgrade` against a kubeconfig
would put production one workflow injection away from CI, which is the
thing the pull model exists to prevent.

## What the version records

`gitops-<env>` is bumped when the pins are **promoted**, not when the
cluster converges — Flux applies asynchronously and nothing here waits for
it. Closing that gap needs a Flux `Alert`/`Provider` notifying GitHub on
reconciliation, which is not wired yet.
