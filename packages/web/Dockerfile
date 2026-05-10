# syntax=docker/dockerfile:1
#
# Multi-stage build on Chainguard distroless images. See api's
# Dockerfile for the rationale.
#
# `pip install .` picks up packages/web/src/shomer_web/{static,
# templates}/ via the [tool.hatch.build.targets.wheel.force-include]
# block in pyproject.toml — those are populated by the web-frontend
# build BEFORE this Docker image is built (see release.yml's
# post_bump hook for web-frontend).

FROM cgr.dev/chainguard/python:latest-dev AS builder

WORKDIR /app
COPY pyproject.toml ./
COPY src ./src

RUN python -m venv /app/venv \
 && /app/venv/bin/pip install --no-cache-dir .

FROM cgr.dev/chainguard/python:latest

COPY --from=builder /app/venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

EXPOSE 8080
ENTRYPOINT ["shomer-web"]
