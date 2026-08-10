# Changelog

All notable changes to this component are documented here.

## [1.0.0] - 2026-08-10

### Breaking changes

- rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)

### Features

- **web**: scaffold fastapi + jinja2 web frontend with login stub (`725ddbb`)
- **dev**: docker compose stack with watch for the whole workspace (`04b31b0`)
- **web**: minify in every mode, inline sourcemap in dev only (`24b88c1`)
- **web**: render the login form as a React island (`d61dcc8`)
- **web**: convert the frontend to a React Router SPA (`c57878d`)
- cut a synchronized release baseline across all components (`eb7f6d3`)
- **web**: publish package metadata (`612a5fd`)

### Fixes

- **web**: migrate biome.json to v2.x schema and allow Jinja interpolation (`e643a20`)
- **dev**: uv cache path + don't rmdir the templates bind mount (`72f9242`)
- **web**: rename the local DOM lookup from `slot` to `errorSlot` (`70379e7`)
- **web**: cap password input length client-side to short-circuit DoS-shaped inputs (`4c7da47`)
- **deps**: bump react-dom from 19.2.7 to 19.2.8 (`a1f4b10`)
- **deps**: bump react-router-dom from 7.18.0 to 7.18.2 (`2ec5272`)

### Dependencies

- Track `lib` `0.1.0`
