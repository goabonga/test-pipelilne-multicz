# syntax=docker/dockerfile:1
#
# Multi-stage build on Chainguard distroless images.
#
# - builder uses python:latest-dev (has pip + shell) to install the
#   wheel into a portable venv at /app/venv. The image runs as the
#   `nonroot` user by default; /app is writable for that user, /venv
#   at the root is not.
# - runtime uses python:latest, a distroless image with no shell, no
#   apt, and the same `nonroot` user (UID 65532). Both images are
#   rebuilt daily and shipped CVE-free by Chainguard.

FROM cgr.dev/chainguard/python:latest-dev@sha256:7a568bcee42666f73f041645a41c913ce1d442f4c24cf6019bc543a90820e531 AS builder

WORKDIR /app
COPY pyproject.toml ./
COPY src ./src

RUN python -m venv /app/venv \
 && /app/venv/bin/pip install --no-cache-dir .

FROM cgr.dev/chainguard/python:latest@sha256:a0365f7b90bf7b78a5e35f2709efb7c9263acf9c7b1905e0ec4c3e943c88e64d

COPY --from=builder /app/venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

EXPOSE 8000

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

LABEL org.opencontainers.image.title="shomer-api" \
      org.opencontainers.image.description="Shomer authorization HTTP API (FastAPI + uvicorn)." \
      org.opencontainers.image.source="https://github.com/goabonga/test-pipelilne-multicz" \
      org.opencontainers.image.url="https://github.com/goabonga/test-pipelilne-multicz" \
      org.opencontainers.image.documentation="https://github.com/goabonga/test-pipelilne-multicz" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="goabonga" \
      org.opencontainers.image.version="$VERSION" \
      org.opencontainers.image.revision="$REVISION" \
      org.opencontainers.image.created="$CREATED"

ENTRYPOINT ["shomer-api"]
