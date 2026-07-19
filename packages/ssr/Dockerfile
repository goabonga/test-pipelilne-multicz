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

FROM cgr.dev/chainguard/python:latest-dev@sha256:31d318170df60ddec4b04ed595cbe79c33eeb2cf94f9676db6f9eaf46542e6be AS builder

WORKDIR /app
COPY pyproject.toml ./
COPY src ./src

RUN python -m venv /app/venv \
 && /app/venv/bin/pip install --no-cache-dir .

FROM cgr.dev/chainguard/python:latest@sha256:2c6a2e8bdeb1336cd8545d3586d1c1e5b4f7564ef00924b0447ebfbe57a549ee

COPY --from=builder /app/venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

EXPOSE 8080
ENTRYPOINT ["shomer-ssr"]
