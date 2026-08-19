// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

import { describe, expect, it } from "vitest";

import * as lib from "../../src/index";

/**
 * The public surface, asserted from the entrypoint.
 *
 * WHY THIS EXISTS
 *
 * Every other test imports its subject directly — `../../src/oidc/pkce`
 * rather than `../../src/index` — because that is what keeps a failure
 * pointing at one module. The cost is that a module which is never
 * exported passes all of them: it compiles, it is tested, and it is
 * unreachable for the app and the React Native adapter that consume this
 * package.
 *
 * That happened here. `discovery` shipped in a commit with no export,
 * fully tested, invisible from outside — and nothing failed. This is the
 * check that would have.
 */
const PUBLIC_SURFACE = [
  // pkce
  "base64UrlEncode",
  "createPkcePair",
  // authorization request
  "createAuthorizationRequest",
  // id token
  "validateIdToken",
  "IdTokenValidationError",
  // session
  "transition",
  "tokensOf",
  "InvalidTransitionError",
  // refresh
  "RefreshManager",
  "needsRefresh",
  "NoRefreshTokenError",
  // discovery
  "OidcDiscovery",
  "wellKnownUrl",
  "DiscoveryError",
] as const;

describe("the package entrypoint", () => {
  it.each(PUBLIC_SURFACE)("exports %s", (name) => {
    expect(lib).toHaveProperty(name);
  });

  it("still exports what it did before OIDC arrived", () => {
    // The OIDC work appends to this file. An append that lands inside the
    // existing block instead of after it would drop these silently.
    expect(lib).toHaveProperty("validateCredentials");
    expect(lib).toHaveProperty("formatError");
  });
});
