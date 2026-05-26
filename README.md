<h1 align="center">
  <img src="docs/shomer.svg" alt="Shomer" width="120" /><br/>
  Shomer
</h1>

<p align="center">
  <em>Multi-tenant OAuth2 / OpenID Connect authorization server.</em>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT"/></a>
  <img src="https://img.shields.io/badge/python-3.11%2B-blue.svg" alt="Python 3.11+"/>
  <img src="https://img.shields.io/badge/FastAPI-async-009688.svg" alt="FastAPI"/>
</p>

---

uv workspace shipping three independently-versioned packages:

| package        | role                          | distribution                         |
|----------------|-------------------------------|--------------------------------------|
| `shomer-api`   | FastAPI authorization server  | Docker image, Helm chart, `.deb`     |
| `shomer-job`| background polling jobs       | Docker image, Helm chart, `.deb`     |
| `shomer-cli`   | operator CLI                  | wheel / sdist (PyPI)                 |

## Quickstart

```bash
uv sync
uv run shomer-api &              # FastAPI on :8000
uv run shomer health http://127.0.0.1:8000
```

## Layout

```
packages/
├── api/      Python source + Dockerfile + chart/ + debian/
├── job/   Python source + Dockerfile + chart/ + debian/
└── cli/      Python source only (no chart, no .deb)
```

Releases are managed by [`multicz`](https://github.com/goabonga/multicz)
— independent tags, independent `CHANGELOG.md`, independent `debian/changelog`
stanzas, mirror cascade from `api` / `job` versions into the matching
`Chart.yaml#appVersion`. See `multicz.toml`.

## License

[MIT](LICENSE).
