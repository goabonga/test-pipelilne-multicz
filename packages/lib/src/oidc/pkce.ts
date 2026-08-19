// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * PKCE — Proof Key for Code Exchange, RFC 7636.
 *
 * WHAT IT IS FOR
 *
 * A public client cannot hold a secret: anything shipped in an app binary
 * or a JS bundle is readable by whoever has the app. So the authorization
 * code alone is the only thing standing between an attacker who
 * intercepts the redirect and a set of tokens.
 *
 * PKCE closes that. The client invents a random `verifier`, sends only its
 * SHA-256 hash with the authorization request, and presents the verifier
 * itself at the token exchange. An intercepted code is useless without the
 * verifier, which never left the device.
 *
 * S256 ONLY. RFC 7636 also defines `plain`, where the challenge IS the
 * verifier — which provides no protection at all against an attacker who
 * can read the authorization request, and exists for clients that cannot
 * compute SHA-256. Offering it here would mean offering a downgrade.
 */

import type { Crypto } from "./ports";

/**
 * Verifier length in bytes before encoding.
 *
 * RFC 7636 §4.1 allows a 43–128 character verifier. 32 random bytes
 * base64url-encode to exactly 43 characters — the minimum the spec allows
 * and already 256 bits of entropy. Going longer buys nothing: the
 * challenge is a SHA-256 hash either way, so anything beyond 256 bits is
 * discarded by the hash.
 */
const VERIFIER_BYTES = 32;

export interface PkcePair {
  /** Kept locally, sent only at the token exchange. */
  readonly verifier: string;
  /** Sent with the authorization request. */
  readonly challenge: string;
  /** Always "S256" — see the note above on `plain`. */
  readonly method: "S256";
}

/**
 * base64url per RFC 4648 §5: the base64 alphabet with `-` and `_`, and no
 * padding.
 *
 * Written out rather than taken from a library because the standard
 * `btoa` is not available in React Native and `Buffer` is not available in
 * a browser — the two platforms this package has to run on. It is a dozen
 * lines and it removes a dependency that would have to work on both.
 */
export function base64UrlEncode(bytes: Uint8Array): string {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
  let out = "";

  for (let i = 0; i < bytes.length; i += 3) {
    const b0 = bytes[i] as number;
    const b1 = i + 1 < bytes.length ? (bytes[i + 1] as number) : undefined;
    const b2 = i + 2 < bytes.length ? (bytes[i + 2] as number) : undefined;

    out += alphabet[b0 >> 2];
    out += alphabet[((b0 & 0x03) << 4) | ((b1 ?? 0) >> 4)];
    if (b1 === undefined) break;
    out += alphabet[((b1 & 0x0f) << 2) | ((b2 ?? 0) >> 6)];
    if (b2 === undefined) break;
    out += alphabet[b2 & 0x3f];
  }

  return out;
}

/**
 * The verifier as bytes.
 *
 * `TextEncoder` would do this and is deliberately not used: it is a
 * DOM/Node global, and this package must not reach for either — the
 * constraint that keeps it loadable in React Native without a polyfill.
 *
 * It is also unnecessary. The verifier is base64url output, so every
 * character is ASCII and its UTF-8 encoding is its char code. This is not
 * a general-purpose UTF-8 encoder and must not be used as one.
 */
function asciiBytes(ascii: string): Uint8Array {
  const bytes = new Uint8Array(ascii.length);
  for (let i = 0; i < ascii.length; i += 1) {
    bytes[i] = ascii.charCodeAt(i);
  }
  return bytes;
}

/**
 * Create a fresh verifier/challenge pair.
 *
 * ONE PAIR PER AUTHORIZATION REQUEST. Reusing a verifier across requests
 * means an attacker who obtains it once can complete every later exchange,
 * which turns PKCE from a defence into a shared secret that is stored on
 * the device.
 */
export async function createPkcePair(crypto: Crypto): Promise<PkcePair> {
  const random = crypto.getRandomValues(new Uint8Array(VERIFIER_BYTES));
  const verifier = base64UrlEncode(random);
  const digest = await crypto.sha256(asciiBytes(verifier));

  return {
    verifier,
    challenge: base64UrlEncode(digest),
    method: "S256",
  };
}
