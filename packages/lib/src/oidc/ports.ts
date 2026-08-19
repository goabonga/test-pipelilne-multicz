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

/**
 * Where tokens live between launches.
 *
 * The platforms disagree about what "securely" means and the difference is
 * not hideable: React Native has the Keychain and the Keystore, a browser
 * has nothing comparable, which is why the SPA half of this design keeps
 * no tokens in JS at all and puts them behind a BFF cookie instead.
 *
 * So this interface is deliberately small — get, set, clear — and says
 * nothing about encryption, biometrics or accessibility classes. Those are
 * decisions the implementation makes with knowledge the core does not
 * have, and a core that pretended to make them would be describing
 * guarantees it cannot keep.
 */
export interface TokenStorage {
  /** Undefined when nothing is stored, not an error. */
  load(): Promise<string | undefined>;
  save(value: string): Promise<void>;
  /** Must succeed when there is nothing to clear — sign-out is idempotent. */
  clear(): Promise<void>;
}

/**
 * Opening the authorization URL and getting the callback back.
 *
 * RFC 8252 REQUIRES THE SYSTEM BROWSER AND FORBIDS AN EMBEDDED WEBVIEW,
 * and the reason is worth stating because a WebView is easier and looks
 * identical to a user:
 *
 *   - the app can read every keystroke and the DOM, so the user has no way
 *     to tell a real IdP page from one the app is watching — which is the
 *     property the whole federation model depends on
 *   - it has no access to the system browser's session, so single sign-on
 *     does not work and the user re-authenticates on every app
 *   - it does not show the address bar, so the user cannot check who they
 *     are giving their credentials to
 *
 * Pro Santé Connect refuses embedded WebViews outright, so this is a
 * conformance requirement here and not only a good practice.
 *
 * The implementation is expected to use ASWebAuthenticationSession on iOS
 * and Custom Tabs on Android — both of which share the browser's cookie
 * jar and hand control back automatically.
 */
export interface Browser {
  /**
   * Open `url` and resolve with the callback URL the IdP redirected to.
   *
   * Resolves with undefined when the user dismissed it. That is not an
   * error: cancelling a login is a thing users do deliberately, and
   * treating it as a failure produces an error dialog for a decision.
   */
  open(url: string, redirectUri: string): Promise<string | undefined>;
}
