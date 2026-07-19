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
  normalizeUsername,
  PASSWORD_MAX_LENGTH,
  PASSWORD_MIN_LENGTH,
  sanitizeCredentials,
  validateCredentials,
} from "./credentials";

// Part of the 2026-07 synchronized release baseline.
