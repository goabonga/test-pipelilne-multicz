# syntax=docker/dockerfile:1
#
# Multi-stage build on Chainguard distroless images. See api's
# Dockerfile for the rationale.

FROM cgr.dev/chainguard/python:latest-dev@sha256:fa7db0816e4dd581d4b4a76edda591804a71788b6a46e46af0b435dad4552642 AS builder

WORKDIR /app
COPY pyproject.toml ./
COPY src ./src

RUN python -m venv /app/venv \
 && /app/venv/bin/pip install --no-cache-dir .

FROM cgr.dev/chainguard/python:latest@sha256:33334c2bf93fd99e6b3c42b518cc44bb5277a954826cdb4f9275ef95818d7eb7

COPY --from=builder /app/venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

ENTRYPOINT ["shomer-job"]
