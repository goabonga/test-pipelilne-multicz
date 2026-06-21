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

FROM cgr.dev/chainguard/python:latest-dev@sha256:1d25aa030b30055e08601392253fb0c9e4e812ad57a37a7a3296624ce3f56da3 AS builder

WORKDIR /app
COPY pyproject.toml ./
COPY src ./src

RUN python -m venv /app/venv \
 && /app/venv/bin/pip install --no-cache-dir .

FROM cgr.dev/chainguard/python:latest@sha256:823531356e8ec4005c9e82c55aace3720457e24b0fcbbb6c4c744a24023ba6eb

COPY --from=builder /app/venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

EXPOSE 8000
ENTRYPOINT ["shomer-api"]
