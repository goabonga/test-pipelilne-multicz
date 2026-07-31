# Changelog — production

What has actually been promoted to `production`. Bumped by the workflow that
moves the pins, and tagged `gitops-production-v<version>`.

Each entry lists the `chart-*` commits the promotion carries, pulled in by
multicz's `upstream-notes` plugin from this component's `depends_on`.

The version records that the pins were **promoted**, not that the cluster
converged — Flux applies asynchronously and nothing here waits on it.
