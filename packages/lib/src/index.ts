// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * Public entrypoint for @shomer/lib.
 *
 * Re-exports the shared, framework-agnostic building blocks consumed by
 * shomer-web (React) and shomer-app (React Native).
 */

export type { Credentials } from "./credentials";
export {
  formatError,
  PASSWORD_MAX_LENGTH,
  PASSWORD_MIN_LENGTH,
  validateCredentials,
} from "./credentials";
