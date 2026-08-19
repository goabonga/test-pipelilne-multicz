// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

import { describe, expect, it } from "vitest";

import { createAuthorizationRequest } from "../../src/oidc/authorization-request";
import type { PkcePair } from "../../src/oidc/pkce";
import type { Crypto } from "../../src/oidc/ports";

const pkce: PkcePair = {
  verifier: "verifier-kept-on-the-device",
  challenge: "challenge-sent-to-the-idp",
  method: "S256",
};

/** Counts up, so state and nonce are distinguishable in assertions. */
function countingCrypto(): Crypto {
  let call = 0;
  return {
    getRandomValues(bytes) {
      call += 1;
      bytes.fill(call);
      return bytes;
    },
    sha256: () => Promise.reject(new Error("not used here")),
  };
}

function params(overrides = {}) {
  return {
    authorizationEndpoint: "https://idp.example/authorize",
    clientId: "shomer",
    redirectUri: "https://app.example/callback",
    scopes: ["openid", "profile"],
    pkce,
    ...overrides,
  };
}

/** Parse the query back out without relying on URL, as the source does. */
function queryOf(url: string): Record<string, string> {
  const [, query = ""] = url.split("?");
  const out: Record<string, string> = {};
  for (const pair of query.split("&")) {
    const [k = "", v = ""] = pair.split("=");
    out[decodeURIComponent(k)] = decodeURIComponent(v);
  }
  return out;
}

describe("createAuthorizationRequest", () => {
  it("sends the challenge and never the verifier", () => {
    // The one thing that would silently undo PKCE: a verifier in the
    // authorization request is a verifier in the browser's history, the
    // IdP's logs, and any referrer that leaks.
    const request = createAuthorizationRequest(params(), countingCrypto());
    const query = queryOf(request.url);

    expect(query.code_challenge).toBe("challenge-sent-to-the-idp");
    expect(query.code_challenge_method).toBe("S256");
    expect(request.url).not.toContain("verifier-kept-on-the-device");
  });

  it("gives state and nonce different values", () => {
    // They defend different things — state ties the callback to this
    // request, nonce ties the ID token to it — so sharing one value means
    // a leak of the callback URL hands over the token binding too.
    const request = createAuthorizationRequest(params(), countingCrypto());

    expect(request.state).not.toBe(request.nonce);
    expect(queryOf(request.url).state).toBe(request.state);
    expect(queryOf(request.url).nonce).toBe(request.nonce);
  });

  it("adds openid when the caller forgot it", () => {
    // Without it the IdP runs plain OAuth2 and returns no ID token, which
    // surfaces much later as a missing claim rather than as a bad request.
    const request = createAuthorizationRequest(params({ scopes: ["profile"] }), countingCrypto());

    expect(queryOf(request.url).scope).toBe("openid profile");
  });

  it("does not add openid twice", () => {
    const request = createAuthorizationRequest(params(), countingCrypto());

    expect(queryOf(request.url).scope).toBe("openid profile");
  });

  it("carries acr_values for an assurance level", () => {
    // Pro Santé Connect uses this to demand the card or a strong second
    // factor. An IdP that receives none may satisfy the request with
    // whatever session it already has.
    const request = createAuthorizationRequest(
      params({ acrValues: ["eidas2", "eidas3"] }),
      countingCrypto(),
    );

    expect(queryOf(request.url).acr_values).toBe("eidas2 eidas3");
  });

  it("omits the optional parameters when they are not given", () => {
    // An empty acr_values or prompt is not the same as an absent one:
    // some IdPs reject the empty string rather than ignoring it.
    const request = createAuthorizationRequest(params(), countingCrypto());
    const query = queryOf(request.url);

    expect(query).not.toHaveProperty("acr_values");
    expect(query).not.toHaveProperty("prompt");
    expect(query).not.toHaveProperty("max_age");
  });

  it("refuses an extra parameter that would overwrite a protocol one", () => {
    // THE assertion here. An IdP-specific extra that replaced
    // code_challenge would disable PKCE, or one that replaced redirect_uri
    // would send the code elsewhere — and the request would still look
    // well-formed in every log.
    expect(() =>
      createAuthorizationRequest(
        params({ extra: { code_challenge: "attacker-controlled" } }),
        countingCrypto(),
      ),
    ).toThrow(/would overwrite a protocol parameter/);
  });

  it("keeps extras that do not collide", () => {
    const request = createAuthorizationRequest(
      params({ extra: { tenant: "chu-lille" } }),
      countingCrypto(),
    );

    expect(queryOf(request.url).tenant).toBe("chu-lille");
  });

  it("appends to an endpoint that already has a query", () => {
    // Some IdPs publish an authorize endpoint with a tenant baked in.
    const request = createAuthorizationRequest(
      params({ authorizationEndpoint: "https://idp.example/authorize?v=2" }),
      countingCrypto(),
    );

    expect(request.url).toContain("?v=2&");
    expect(queryOf(request.url).v).toBe("2");
    expect(queryOf(request.url).client_id).toBe("shomer");
  });

  it("escapes values rather than letting them break the query", () => {
    // A redirect_uri contains :// and often a query of its own. Unescaped,
    // it would truncate everything after it — including code_challenge.
    const request = createAuthorizationRequest(
      params({ redirectUri: "https://app.example/cb?next=/a&b=1" }),
      countingCrypto(),
    );

    expect(queryOf(request.url).redirect_uri).toBe("https://app.example/cb?next=/a&b=1");
    expect(queryOf(request.url).code_challenge).toBe("challenge-sent-to-the-idp");
  });
});
