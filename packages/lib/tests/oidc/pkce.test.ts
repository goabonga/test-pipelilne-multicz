// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

import { describe, expect, it } from "vitest";

import { base64UrlEncode, createPkcePair } from "../../src/oidc/pkce";
import type { Crypto } from "../../src/oidc/ports";

/**
 * WebCrypto, declared narrowly here rather than by adding @types/node.
 *
 * One tsconfig covers src and tests, so pulling Node's types in for the
 * test would put Node globals within reach of the source — and the whole
 * point of the injected Crypto port is that the source cannot reach for
 * them. `globalThis.crypto` is WebCrypto in Node 19+, in browsers and in
 * Hermes, which is exactly the set of platforms this package targets.
 */
const webcrypto = (
  globalThis as unknown as {
    crypto: {
      subtle: { digest(alg: string, data: Uint8Array): Promise<ArrayBuffer> };
    };
  }
).crypto;

/**
 * A deterministic Crypto, so the assertions below are about the algorithm
 * rather than about whatever the platform's randomness happened to
 * produce. The hash is real; only the randomness is fixed.
 */
function fixedCrypto(seed: number): Crypto {
  return {
    getRandomValues(bytes) {
      for (let i = 0; i < bytes.length; i += 1) {
        bytes[i] = (seed + i) % 256;
      }
      return bytes;
    },
    async sha256(data) {
      return new Uint8Array(await webcrypto.subtle.digest("SHA-256", data));
    },
  };
}

describe("base64UrlEncode", () => {
  it("uses the url alphabet and no padding", () => {
    // 0xfb 0xff produces '+' and '/' under standard base64 and '-' and '_'
    // under base64url — the one pair of bytes that tells the two apart.
    const encoded = base64UrlEncode(new Uint8Array([0xfb, 0xff, 0xfe]));

    expect(encoded).not.toContain("+");
    expect(encoded).not.toContain("/");
    expect(encoded).not.toContain("=");
    expect(encoded).toBe("-__-");
  });

  it("encodes lengths that are not a multiple of three", () => {
    // The remainder cases are where a hand-written encoder goes wrong, and
    // a wrong verifier fails only at the token exchange — far from here.
    expect(base64UrlEncode(new Uint8Array([0x61]))).toBe("YQ");
    expect(base64UrlEncode(new Uint8Array([0x61, 0x62]))).toBe("YWI");
    expect(base64UrlEncode(new Uint8Array([0x61, 0x62, 0x63]))).toBe("YWJj");
  });
});

describe("createPkcePair", () => {
  it("produces a verifier the RFC accepts", async () => {
    const pair = await createPkcePair(fixedCrypto(0));

    // RFC 7636 §4.1: 43 to 128 characters. 32 random bytes encode to
    // exactly 43, the shortest the spec allows.
    expect(pair.verifier).toHaveLength(43);
    expect(pair.verifier).toMatch(/^[A-Za-z0-9\-._~]+$/);
  });

  it("only ever offers S256", async () => {
    const pair = await createPkcePair(fixedCrypto(0));

    // RFC 7636 also defines `plain`, where the challenge IS the verifier
    // and an attacker who reads the authorization request has everything.
    // Offering it would be offering a downgrade.
    expect(pair.method).toBe("S256");
    expect(pair.challenge).not.toBe(pair.verifier);
  });

  it("hashes the verifier rather than sending it", async () => {
    const pair = await createPkcePair(fixedCrypto(7));

    const expected = new Uint8Array(
      await webcrypto.subtle.digest(
        "SHA-256",
        Uint8Array.from(pair.verifier, (c) => c.charCodeAt(0)),
      ),
    );

    expect(pair.challenge).toBe(base64UrlEncode(expected));
  });

  it("matches the worked example in RFC 7636 Appendix B", async () => {
    // The strongest assertion available here: the spec publishes one
    // verifier and the challenge it must produce. Passing it means the
    // encoding, the hash and the byte handling all agree with the
    // document every IdP implements against — not merely with each other.
    const verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";

    const digest = new Uint8Array(
      await webcrypto.subtle.digest(
        "SHA-256",
        Uint8Array.from(verifier, (c) => c.charCodeAt(0)),
      ),
    );

    expect(base64UrlEncode(digest)).toBe("E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM");
  });

  it("never repeats a pair across calls", async () => {
    // THE assertion. A reused verifier means an attacker who obtains it
    // once can complete every later exchange — PKCE stops being a defence
    // and becomes a long-lived secret stored on the device.
    const a = await createPkcePair(fixedCrypto(1));
    const b = await createPkcePair(fixedCrypto(2));

    expect(a.verifier).not.toBe(b.verifier);
    expect(a.challenge).not.toBe(b.challenge);
  });
});
