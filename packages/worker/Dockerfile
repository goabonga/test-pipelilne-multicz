# syntax=docker/dockerfile:1
FROM python:3.12-slim AS runtime

WORKDIR /app
RUN pip install --no-cache-dir uv

COPY pyproject.toml ./
COPY src ./src

RUN uv pip install --system --no-cache .

USER 1000:1000
ENTRYPOINT ["shomer-worker"]
