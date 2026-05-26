# syntax=docker/dockerfile:1
#
# Multi-stage build on Chainguard distroless images. See api's
# Dockerfile for the rationale.

# hadolint ignore=DL3007
FROM cgr.dev/chainguard/python:latest-dev AS builder

WORKDIR /app
COPY pyproject.toml ./
COPY src ./src

RUN python -m venv /app/venv \
 && /app/venv/bin/pip install --no-cache-dir .

# hadolint ignore=DL3007
FROM cgr.dev/chainguard/python:latest

COPY --from=builder /app/venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

ENTRYPOINT ["shomer-job"]
