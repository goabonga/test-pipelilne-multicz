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

FROM cgr.dev/chainguard/python:latest-dev@sha256:d45c16a1807036a402f2101a1e82863468c923d85a2ed4817b2b12b2f0ee54dd AS builder

ARG DRIVER=postgres

WORKDIR /app
COPY database ./database
COPY migrations ./migrations

RUN python -m venv /app/venv \
 && /app/venv/bin/pip install --no-cache-dir "./database[${DRIVER}]" ./migrations

FROM cgr.dev/chainguard/python:latest@sha256:6a9e1eed2c9f3ea955a63455c0417a2177f5ce669d2587da6f7d01d738c683d6

COPY --from=builder /app/venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

ENTRYPOINT ["shomer-migrate"]
