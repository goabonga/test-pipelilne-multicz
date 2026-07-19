# Changelog

All notable changes to this component are documented here.

## [1.3.0] - 2026-07-19

### Features

- cut a synchronized release baseline across all components (`eb7f6d3`)

### Dependencies

- Track `lib` `0.5.0`

## [1.2.3] - 2026-06-21

### Dependencies

- Track `lib` `0.4.0`

## [1.2.2] - 2026-06-21

### Dependencies

- Track `lib` `0.3.0`

## [1.2.1] - 2026-06-21

### Dependencies

- Track `lib` `0.2.0`

## [1.2.0] - 2026-06-21

### Features

- **web**: render the login form as a React island (`d61dcc8`)
- **web**: convert the frontend to a React Router SPA (`c57878d`)

### Dependencies

- Track `lib` `0.1.0`

## [1.1.2] - 2026-06-14

### Fixes

- **web**: cap password input length client-side to short-circuit DoS-shaped inputs (`4c7da47`)

## [1.1.1] - 2026-06-13

### Fixes

- **web**: rename the local DOM lookup from `slot` to `errorSlot` (`70379e7`)

## [1.1.0] - 2026-06-13

### Features

- **dev**: docker compose stack with watch for the whole workspace (`04b31b0`)
- **web**: minify in every mode, inline sourcemap in dev only (`24b88c1`)

### Fixes

- **dev**: uv cache path + don't rmdir the templates bind mount (`72f9242`)

## [1.1.0] - 2026-06-13

### Features

- **dev**: docker compose stack with watch for the whole workspace (`04b31b0`)
- **web**: minify in every mode, inline sourcemap in dev only (`24b88c1`)

### Fixes

- **dev**: uv cache path + don't rmdir the templates bind mount (`72f9242`)

## [1.0.1] - 2026-06-13

### Fixes

- **web**: migrate biome.json to v2.x schema and allow Jinja interpolation (`e643a20`)

## [1.0.0] - 2026-05-27

### Breaking changes

- rename components (worker->job, web->ssr, web-frontend->web) (`ba4d5b8`)

### Features

- **web**: scaffold fastapi + jinja2 web frontend with login stub (`725ddbb`)

### Fixes

- **web**: migrate biome.json to v2.x schema and allow Jinja interpolation (`ad96ad5`)
