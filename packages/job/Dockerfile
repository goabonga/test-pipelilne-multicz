# syntax=docker/dockerfile:1
#
# Multi-stage build on Chainguard distroless images. See api's
# Dockerfile for the rationale.

FROM cgr.dev/chainguard/python:latest-dev@sha256:d45c16a1807036a402f2101a1e82863468c923d85a2ed4817b2b12b2f0ee54dd AS builder

WORKDIR /app
COPY pyproject.toml ./
COPY src ./src

RUN python -m venv /app/venv \
 && /app/venv/bin/pip install --no-cache-dir .

FROM cgr.dev/chainguard/python:latest@sha256:6a9e1eed2c9f3ea955a63455c0417a2177f5ce669d2587da6f7d01d738c683d6

COPY --from=builder /app/venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

ENTRYPOINT ["shomer-job"]
