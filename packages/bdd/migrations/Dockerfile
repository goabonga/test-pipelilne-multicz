# syntax=docker/dockerfile:1
#
# Migration-runner image. This is the ONLY artifact that bundles Alembic and the
# revisions — api / job depend on the shomer-database wheel (models + connector)
# and carry neither.
#
# Build context is packages/bdd (it needs the sibling shomer-database, a
# workspace package not on PyPI):
#   docker build -f packages/bdd/migrations/Dockerfile -t shomer-migrations packages/bdd
#
# The entrypoint runs `alembic upgrade head` (shomer-migrate) against the
# database in SHOMER_BDD_* env: pending revisions only, never recreates.
#
# DRIVER selects the DB driver. postgres (psycopg) and mysql (PyMySQL) work on
# distroless; mssql/pyodbc needs system unixODBC + a different base.

FROM cgr.dev/chainguard/python:latest-dev@sha256:7a568bcee42666f73f041645a41c913ce1d442f4c24cf6019bc543a90820e531 AS builder

ARG DRIVER=postgres

WORKDIR /app
COPY database ./database
COPY migrations ./migrations

RUN python -m venv /app/venv \
 && /app/venv/bin/pip install --no-cache-dir "./database[${DRIVER}]" ./migrations

FROM cgr.dev/chainguard/python:latest@sha256:a0365f7b90bf7b78a5e35f2709efb7c9263acf9c7b1905e0ec4c3e943c88e64d

COPY --from=builder /app/venv /app/venv
ENV PATH="/app/venv/bin:$PATH"


# OCI annotations. Declared here rather than in the workflow so that
# `docker build` produces them locally too, and — since the Dockerfile is
# in this component's multicz `paths` — so that changing them actually
# releases a new image carrying them.
#
# The three values that cannot be static are passed as build args by the
# `<component>-container` CI job; a local build simply leaves them empty.
ARG VERSION=""
ARG REVISION=""
ARG CREATED=""

LABEL org.opencontainers.image.title="shomer-migrations" \
      org.opencontainers.image.description="Shomer database migrations (Alembic)." \
      org.opencontainers.image.source="https://github.com/goabonga/test-pipelilne-multicz" \
      org.opencontainers.image.url="https://github.com/goabonga/test-pipelilne-multicz" \
      org.opencontainers.image.documentation="https://github.com/goabonga/test-pipelilne-multicz" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="goabonga" \
      org.opencontainers.image.version="$VERSION" \
      org.opencontainers.image.revision="$REVISION" \
      org.opencontainers.image.created="$CREATED"

ENTRYPOINT ["shomer-migrate"]
