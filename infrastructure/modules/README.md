# Terraform modules

Local Terraform modules consumed by the Terragrunt units under
[`../services/`](../services). Each module lives in its own subdirectory
with the standard `main.tf` / `variables.tf` / `outputs.tf` / `versions.tf`
layout, plus a `README.md`, a `CHANGELOG.md`, a `.terraform-docs.yml` and
`tests/*.tftest.hcl` — every module is versioned, changelogged and tagged
independently by multicz (`infra-modules-<name>-v<version>`, see
[`../../multicz.toml`](../../multicz.toml)).

A module is a **library**: it releases immediately on every push to `main`
that touches it. That is the opposite of `configs-staging` /
`configs-production`, which represent deployed state and release only after
a real apply.

## Adding a module

```bash
make infra-new-module NAME=<name>       # or: scripts/new-terraform-module.sh <name>
```

That copies `_template/`, generates its `README.md` with terraform-docs,
appends a `[components.infra-modules-<name>]` block to `multicz.toml`, adds
the component to every `configs-<env>`'s `depends_on` (so multicz's
`upstream-notes` plugin lists the module's commits in each environment's
deploy changelog), and runs `multicz validate --strict`. Then:

1. declare the resources in `main.tf`;
2. replace the placeholder in `tests/` with real assertions;
3. consume it from a unit under `../services/`, behind the `enabled`
   toggle;
4. add that unit's block to `../configs/staging/config.yaml` and
   `../configs/production/config.yaml`.

`_template/` is not a real module. It is deliberately **not** registered as
its own multicz component — it ships as part of `infra`, alongside the
Terragrunt root wiring it belongs to.

## Version and generated docs

A module's version lives in **`README.md`**, on a single line:

```markdown
**Version:** 0.1.0
```

There is no `VERSION` file. multicz rewrites that line on bump (a `regex:`
`bump_files` entry), then a `post_bump` hook re-runs terraform-docs, so a
released module always ships documentation matching the code that was
tagged.

Each module carries its own `.terraform-docs.yml` in `inject` mode, which
rewrites **only** what sits between the `BEGIN_TF_DOCS` / `END_TF_DOCS`
markers. Everything else in the README — the version line, the description,
the usage example — is hand-written and survives regeneration. Anything you
put *between* the markers is lost on the next run.

```bash
make infra-docs         # regenerate every module README
make infra-docs-check   # verify they are up to date (what CI runs)
```

The CI check exists because the failure is silent otherwise: add a variable
without regenerating, and the next release publishes a README describing
the previous interface.

## Testing

```bash
make infra-test        # terraform test in every module that has a tests/ dir
```

Tests run offline: `mock_provider` intercepts every provider call, so no
credentials and no network are needed. This is what the `infra-test` CI job
runs, and it is why that job needs no cloud login.

## No provider yet

No cloud provider is wired (see
[`../services/terragrunt.hcl`](../services/terragrunt.hcl)). Consequences
while that holds:

- `versions.tf` declares `required_version` only, no `required_providers`.
  Add that block **per module** when a provider is chosen — never generate
  it from the Terragrunt root, or Terraform trips on a duplicate providers
  configuration in the same working directory.
- state is local and thrown away with the `.terragrunt-cache`, so every
  plan looks like a first apply.
