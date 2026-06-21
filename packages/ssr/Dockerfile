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

FROM cgr.dev/chainguard/python:latest-dev@sha256:1d25aa030b30055e08601392253fb0c9e4e812ad57a37a7a3296624ce3f56da3 AS builder

WORKDIR /app
COPY pyproject.toml ./
COPY src ./src

RUN python -m venv /app/venv \
 && /app/venv/bin/pip install --no-cache-dir .

FROM cgr.dev/chainguard/python:latest@sha256:823531356e8ec4005c9e82c55aace3720457e24b0fcbbb6c4c744a24023ba6eb

COPY --from=builder /app/venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

EXPOSE 8080
ENTRYPOINT ["shomer-ssr"]
