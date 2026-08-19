// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

import { describe, expect, it } from "vitest";

import {
  type IdTokenClaims,
  IdTokenValidationError,
  type JwtVerifier,
  validateIdToken,
} from "../../src/oidc/id-token";
import type { Clock } from "../../src/oidc/ports";

const NOW_SECONDS = 1_760_000_000;
const clock: Clock = { now: () => NOW_SECONDS * 1000 };

function verifierFor(claims: Partial<IdTokenClaims>): JwtVerifier {
  return {
    verify: async () =>
      ({
        iss: "https://idp.example",
        sub: "user-1",
        aud: "shomer",
        exp: NOW_SECONDS + 300,
        iat: NOW_SECONDS - 10,
        nonce: "the-nonce",
        ...claims,
      }) as IdTokenClaims,
  };
}

const params = {
  issuer: "https://idp.example",
  clientId: "shomer",
  nonce: "the-nonce",
};

async function expectRejection(claims: Partial<IdTokenClaims>, reason: string, overrides = {}) {
  await expect(
    validateIdToken("token", { ...params, ...overrides }, verifierFor(claims), clock),
  ).rejects.toMatchObject({ reason });
}

describe("validateIdToken", () => {
  it("accepts a token that satisfies every claim", async () => {
    const claims = await validateIdToken("token", params, verifierFor({}), clock);

    expect(claims.sub).toBe("user-1");
  });

  it("checks the signature before reading any claim", async () => {
    // Reading claims out of an unverified token and acting on them turns a
    // validator into a parser for attacker-controlled input.
    const verifier: JwtVerifier = {
      verify: () => Promise.reject(new Error("bad signature")),
    };

    await expect(validateIdToken("token", params, verifier, clock)).rejects.toThrow(
      "bad signature",
    );
  });

  it("rejects a token from another issuer", async () => {
    await expectRejection({ iss: "https://evil.example" }, "issuer");
  });

  it("rejects a token minted for another client", async () => {
    // Its owner could otherwise replay it against us and be accepted as
    // whoever the token names.
    await expectRejection({ aud: "some-other-app" }, "audience");
  });

  it("accepts an audience array that includes this client", async () => {
    const claims = await validateIdToken(
      "token",
      params,
      verifierFor({ aud: ["shomer", "another-app"], azp: "shomer" }),
      clock,
    );

    expect(claims.sub).toBe("user-1");
  });

  it("rejects a multi-audience token authorized for someone else", async () => {
    // Being IN the audience is not being the intended recipient. azp is
    // what settles it, and skipping the check is how a token meant for a
    // sibling application is accepted here.
    await expectRejection(
      { aud: ["shomer", "another-app"], azp: "another-app" },
      "authorized_party",
    );
  });

  it("rejects an expired token", async () => {
    await expectRejection({ exp: NOW_SECONDS - 3600 }, "expired");
  });

  it("allows a little clock skew but not a lot", async () => {
    // Just expired, within tolerance — a device whose clock is seconds out
    // should still work.
    const claims = await validateIdToken(
      "token",
      params,
      verifierFor({ exp: NOW_SECONDS - 30 }),
      clock,
    );
    expect(claims.sub).toBe("user-1");

    // Well past it. Every second of tolerance is a second an expired token
    // stays acceptable, so the window is deliberately small.
    await expectRejection({ exp: NOW_SECONDS - 120 }, "expired");
  });

  it("rejects a token issued in the future", async () => {
    // Not a clock quirk to shrug at — it is what a forged token looks like
    // when the forger's clock is wrong.
    await expectRejection({ iat: NOW_SECONDS + 3600 }, "issued_in_future");
  });

  it("rejects a token from another authorization request", async () => {
    await expectRejection({ nonce: "a-different-nonce" }, "nonce");
  });

  it("rejects a token with no nonce at all", async () => {
    // THE assertion. Treating an absent nonce as acceptable means an
    // attacker who can strip the claim strips the check with it.
    await expectRejection({ nonce: undefined }, "nonce");
  });

  it("enforces max_age when it was requested", async () => {
    await expectRejection({ auth_time: NOW_SECONDS - 7200 }, "auth_time", { maxAgeSeconds: 300 });
  });

  it("refuses to assume freshness when auth_time is missing", async () => {
    // Asking for max_age and accepting a token that cannot answer it is
    // the same as not asking.
    await expectRejection({ auth_time: undefined }, "auth_time", {
      maxAgeSeconds: 300,
    });
  });

  it("accepts a recent authentication under max_age", async () => {
    const claims = await validateIdToken(
      "token",
      { ...params, maxAgeSeconds: 300 },
      verifierFor({ auth_time: NOW_SECONDS - 60 }),
      clock,
    );

    expect(claims.sub).toBe("user-1");
  });

  it("reports a machine-readable reason", async () => {
    // So a caller can branch on "expired" — worth a silent refresh — versus
    // "issuer", which is not.
    const error = await validateIdToken(
      "token",
      params,
      verifierFor({ exp: NOW_SECONDS - 3600 }),
      clock,
    ).catch((e: unknown) => e);

    expect(error).toBeInstanceOf(IdTokenValidationError);
    expect((error as IdTokenValidationError).reason).toBe("expired");
  });
});
