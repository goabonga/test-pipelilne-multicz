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

FROM cgr.dev/chainguard/python:latest-dev@sha256:31d318170df60ddec4b04ed595cbe79c33eeb2cf94f9676db6f9eaf46542e6be AS builder

ARG DRIVER=postgres

WORKDIR /app
COPY database ./database
COPY migrations ./migrations

RUN python -m venv /app/venv \
 && /app/venv/bin/pip install --no-cache-dir "./database[${DRIVER}]" ./migrations

FROM cgr.dev/chainguard/python:latest@sha256:2c6a2e8bdeb1336cd8545d3586d1c1e5b4f7564ef00924b0447ebfbe57a549ee

COPY --from=builder /app/venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

ENTRYPOINT ["shomer-migrate"]
