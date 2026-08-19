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

// ── OIDC ────────────────────────────────────────────────────────────────
//
// The platform-free half of the authentication flow. Everything here is
// pure TypeScript against injected interfaces, so the same code runs in
// the React Native app and in the browser bundle — which is the point:
// two clients that disagree about how a token is validated are two
// clients with two different security postures.

export type { PkcePair } from "./oidc/pkce";
export { base64UrlEncode, createPkcePair } from "./oidc/pkce";
export type { Clock, Crypto } from "./oidc/ports";
