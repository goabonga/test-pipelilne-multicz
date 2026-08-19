// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * Everything the OIDC core needs from the outside, and nothing more.
 *
 * WHY THESE ARE INTERFACES
 *
 * This package is consumed by a React Native app and by a browser bundle.
 * Those two have no crypto API in common: React Native has no
 * `globalThis.crypto.subtle` without a polyfill, and Node before 19 has it
 * only under `node:crypto`. A core that imported either would compile and
 * then fail at runtime on the other platform — which is the failure mode
 * this whole indirection exists to avoid.
 *
 * Injecting them also makes the tests deterministic: a fixed clock and a
 * seeded random source turn "did it build the right URL" into something
 * that can be asserted rather than approximated.
 */

/** The randomness and hashing PKCE needs. */
export interface Crypto {
  /**
   * Fill a buffer with cryptographically secure random bytes.
   *
   * NOT `Math.random()` under any circumstances. A predictable verifier
   * lets anyone who observes the authorization request complete the
   * exchange, which is the single thing PKCE is for.
   */
  getRandomValues(bytes: Uint8Array): Uint8Array;

  /** SHA-256 of the given bytes. Async because WebCrypto's is. */
  sha256(data: Uint8Array): Promise<Uint8Array>;
}

/**
 * Time, injected so expiry logic can be tested without waiting for it.
 *
 * Every token decision here is a comparison against this, never against
 * `Date.now()` directly — otherwise "does it refresh five minutes early"
 * is a test that takes five minutes.
 */
export interface Clock {
  /** Milliseconds since the Unix epoch. */
  now(): number;
}
