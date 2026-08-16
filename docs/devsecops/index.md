---
icon: lucide/shield-check
---

# For DevSecOps

What runs, what it is actually asserting, and where each gate stops being
useful.

## The gates

| gate | scope | what it would catch |
|---|---|---|
| `ruff`, `biome` | Python, TypeScript | lint, format |
| `bandit` | Python | insecure patterns in source |
| `hadolint` | Dockerfiles | build practices |
| `gitleaks` | the tree | committed secrets |
| `mobsfscan` | the React Native app | mobile-specific patterns |
| SBOM + `grype` | every image | known CVEs in what actually shipped |
| `checkov` | charts, Terraform modules | misconfiguration |
| Kyverno | charts | that image verification is enforced |
| `cosign` | images, charts | that the artefact came from this repository |
| `terraform test` | 24 modules | the properties the design depends on |

## The two that assert more than they appear to

**The chart policy test.** It stands up Kyverno in a throwaway cluster with
`Enforce` on, presents an image the policy matches, and requires it to be
rejected — then requires it to be admitted once the policy is switched off.
A policy that admits everything passes every test that only checks it is
installed, which is the failure this exists to catch.

**The `.deb` install test.** It installs the package in a clean container
and asserts the reported version is the one the build was told to produce.

## Signing, and what is anchored

Images and charts are signed keylessly with cosign. The Flux `HelmRelease`
verifies both the **issuer and the identity**:

```yaml
verify:
  provider: cosign
  matchOIDCIdentity:
    - issuer: "^https://token\\.actions\\.githubusercontent\\.com$"
      subject: "^https://github\\.com/goabonga/test-pipelilne-multicz/.*$"
```

Pinning the issuer alone would accept a signature from any GitHub workflow
in any repository — which is to say, from anyone.

## Network policy is enforced in two layers

Neither substitutes for the other:

- **Terraform** controls node-to-world: routes, firewall rules, the proxy's
  allow-list, NAT scope.
- **Kubernetes** controls pod-to-pod: a default-deny floor plus per-release
  rules.

The floor has a trap worth knowing: **NetworkPolicy is additive.** A
deny-all does not override a permissive policy, it unions with it. The
charts default to allow-from-anywhere, so one release left at that default
opts its pod out of the floor while the floor still reads as a deny-all.
`scripts/check-network-invariants.py` fails CI on exactly that, and on a
policy whose proxy subnet or port has drifted from the environment config.

## Where the environments differ, and why

Production runs Cilium installed by this repository, so it enforces layer-7
HTTP rules and FQDN egress. Staging runs GKE Dataplane V2 — which *is*
Cilium, but managed by Google, which does not install the upstream CRDs. A
`CiliumNetworkPolicy` applied to staging is accepted by nothing and
silently absent.

That divergence follows from the cluster modules rather than from a
preference, and it means staging is a weaker test of policy than
production is a deployment of it.

## Exceptions

Every gate here can be excepted, and each has its own mechanism and its own
rules about expiry: [creating an exception](exceptions.md).
