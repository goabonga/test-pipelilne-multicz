# Changelog — bootstrap/aws

The AWS state backend bootstrap. Applied by hand, once, with local state —
it creates the bucket every other unit then uses as its backend. See
[`../README.md`](../README.md).

## [0.2.0] - 2026-08-13

### Features

- **infra**: let CI reach both clouds without a stored key (`579ff26`)

### Fixes

- **infra**: publish the region the environment runs in, and stop the endless diff (`96b689f`)

## [0.1.0] - 2026-08-11

### Features

- **infra**: bootstrap the state backend for AWS and GCP (`fc631c5`)
