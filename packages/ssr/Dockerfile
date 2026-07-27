# syntax=docker/dockerfile:1
#
# Multi-stage build on Chainguard distroless images. See api's
# Dockerfile for the rationale.
#
# `pip install .` picks up packages/ssr/src/shomer_ssr/{static,
# templates}/ via the [tool.hatch.build.targets.wheel.force-include]
# block in pyproject.toml — those are populated by the web
# build BEFORE this Docker image is built (see release.yml's
# post_bump hook for web).

FROM cgr.dev/chainguard/python:latest-dev@sha256:7a568bcee42666f73f041645a41c913ce1d442f4c24cf6019bc543a90820e531 AS builder

WORKDIR /app
COPY pyproject.toml ./
COPY src ./src

RUN python -m venv /app/venv \
 && /app/venv/bin/pip install --no-cache-dir .

FROM cgr.dev/chainguard/python:latest@sha256:a0365f7b90bf7b78a5e35f2709efb7c9263acf9c7b1905e0ec4c3e943c88e64d

COPY --from=builder /app/venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

EXPOSE 8080
ENTRYPOINT ["shomer-ssr"]
