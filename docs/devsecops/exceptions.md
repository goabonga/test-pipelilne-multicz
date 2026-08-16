---
icon: lucide/file-warning
---

# Creating an exception

Every gate can be excepted. Each has a different mechanism, and the
difference that matters is whether the exception **expires by itself** —
because the ones that do not are the ones still in place three years later
protecting nothing.

## The rule that applies to all of them

**Write the reason, not the rule id.** A suppression that says
`CKV_AWS_23: false positive` tells the next reader nothing they could act
on. One that says *why the check does not apply here, and what would make
it apply again*, is the difference between an exception and a hole.

Every example below is taken from this repository.

## grype — vulnerabilities in a shipped image

Per component, in `packages/<name>/.grype.yaml`. **Two things are
mandatory** and the tooling enforces both:

```yaml
ignore:
  # CVE-2026-54876 — OpenSSL, High. No patched apk exists: Chainguard's
  # current python:latest digest still ships 3.6.3-r3, so bumping the base
  # image does not clear it.
  #
  # The version pin is what resolves this automatically: the moment a
  # patched libcrypto3 ships, the version stops matching and the CVE
  # surfaces again under --fail-on high.
  # expires: 2026-11-09
  - vulnerability: CVE-2026-54876
    package:
      name: libcrypto3
      version: 3.6.3-r3
```

- The `# expires:` marker is read by a weekly sweep
  (`scripts/grype-allowlist-sweep.py`). It greps for that literal string,
  so a date buried in prose is a date nobody enforces.
- The **version pin** is what makes the exception self-resolving. When a
  patched package ships, the version no longer matches, the ignore stops
  applying, and the CVE fails the build again — without anyone remembering
  to go back.

An ignore without a version pin suppresses the CVE forever, including on
the patched release.

## checkov — infrastructure and chart misconfiguration

Inline, on the resource, with the reason on the same comment:

```hcl
resource "aws_security_group" "workload" {
  # checkov:skip=CKV2_AWS_5: Attached by services/k8s/nodes, which depends
  # on this unit — checkov cannot see across the module boundary. The
  # caveat is real and worth stating: nothing HERE forces that consumer to
  # exist, so a group with no members is a possible state.
```

Checkov skips do not expire. Treat that as a reason to be strict about
which ones earn a skip:

- **A module-boundary false positive** — the check looks for something that
  exists in a unit checkov is not scanning. Legitimate, and say which unit.
- **A check that measures the wrong thing for this case** — for example
  load balancer access logs on a forward proxy, where the record that
  answers "what was requested?" is the proxy's own log. Legitimate, and say
  what the right record is.
- **"It is inconvenient"** — not legitimate. Fix it or accept the failure.

When a check is right, fix it instead. Six of checkov's findings on the GKE
cluster module were real; five were fixed and one was skipped, and that
ratio is roughly what to expect.

## bandit — Python

Inline, with the specific test id:

```python
uvicorn.run("shomer_api.app:app", host="0.0.0.0", port=8000)  # nosec B104
```

A bare `# nosec` disables every check on that line, including ones added
later. Always name the id.

## ruff — Python lint

```python
value = compute()  # noqa: E501
```

Same principle: name the rule. A bare `# noqa` is a blanket.

## hadolint — Dockerfiles

```dockerfile
# hadolint ignore=DL3008
RUN apt-get install -y --no-install-recommends squid
```

The ignore applies to the next instruction only, which is the right scope.

## gitleaks — committed secrets

There is no allowlist in this repository, and adding one deserves more
scrutiny than any other exception here. A gitleaks finding is either a real
secret — in which case **rotate it first**, because it is in the git
history whatever you do to the working tree — or a test fixture that should
not look like a credential.

If a fixture genuinely must, make it obviously fake (`AKIAIOSFODNN7EXAMPLE`)
rather than allowlisting a real-looking string.

## Kyverno — admission policy

Per chart, in `values.yaml`:

```yaml
validationFailureAction: Audit
```

`Audit` records violations instead of rejecting them. It is the right
setting while a policy is being rolled out and the wrong one to leave
behind, because a policy in `Audit` passes every test that checks it is
installed. The CI job for each chart proves the policy is in `Enforce` and
actually rejects — see [the gates](index.md).

## terraform test — an expected failure

Not an exception so much as its opposite: asserting that something is
refused.

```hcl
run "a_public_cidr_is_refused" {
  command = plan
  variables { cidr = "172.15.0.0/16" }
  expect_failures = [aws_vpc.this]
}
```

If a precondition fires where it should not, the fix is the precondition,
not a suppression. A module that refuses a legitimate configuration is a
bug in the module.

## Network policy invariants

`scripts/check-network-invariants.py` has no exception mechanism, and that
is deliberate. It checks that two files describing the same boundary agree.
There is no situation where they should disagree — if the check is wrong,
the check is wrong and should be fixed.

## Reviewing an exception

When one appears in a pull request, three questions:

1. **Does the reason say why the check does not apply**, or only that it
   failed?
2. **Will it resolve by itself?** If the mechanism supports expiry or a
   version pin, is it used?
3. **What would have to change for this to become wrong again**, and would
   anything notice?

The third is the one that matters. An exception that nothing will ever
re-examine is a permanent decision written in a temporary voice.
