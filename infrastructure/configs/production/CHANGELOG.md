# Changelog — production

What has actually been applied to the `production` environment. Unlike the other
components, this one is not a library: it is bumped only by
`.github/workflows/infra-apply.yml` after a successful `terragrunt apply`,
and tagged `configs-production-v<version>`.

Each entry also lists the `infra` / `infra-modules-*` commits that deploy
shipped — pulled in by multicz's `upstream-notes` plugin from this
component's `depends_on` (see `multicz.toml`).
