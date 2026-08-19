// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

import { describe, expect, it, vi } from "vitest";

import { DiscoveryError, type Fetch, OidcDiscovery, wellKnownUrl } from "../../src/oidc/discovery";
import type { Clock } from "../../src/oidc/ports";

const NOW = 1_760_000_000_000;
const ISSUER = "https://psc.example";

function document(overrides: Record<string, unknown> = {}) {
  return {
    issuer: ISSUER,
    authorization_endpoint: `${ISSUER}/authorize`,
    token_endpoint: `${ISSUER}/token`,
    jwks_uri: `${ISSUER}/jwks`,
    code_challenge_methods_supported: ["S256"],
    ...overrides,
  };
}

function fetchReturning(body: unknown, ok = true, status = 200): Fetch {
  return vi.fn(async () => ({ ok, status, json: async () => body }));
}

function movableClock(): Clock & { advance(ms: number): void } {
  let now = NOW;
  return {
    now: () => now,
    advance(ms) {
      now += ms;
    },
  };
}

describe("wellKnownUrl", () => {
  it("appends the path to the issuer, per RFC 8414", () => {
    expect(wellKnownUrl("https://psc.example")).toBe(
      "https://psc.example/.well-known/openid-configuration",
    );
  });

  it("does not produce a double slash", () => {
    // Some IdPs 404 on it, which reads as the IdP being down.
    expect(wellKnownUrl("https://psc.example/")).toBe(
      "https://psc.example/.well-known/openid-configuration",
    );
  });

  it("keeps a path-bearing issuer intact", () => {
    // A tenant-scoped issuer is a path, not an origin — dropping it would
    // fetch another tenant's document.
    expect(wellKnownUrl("https://idp.example/tenant/a")).toBe(
      "https://idp.example/tenant/a/.well-known/openid-configuration",
    );
  });
});

describe("OidcDiscovery", () => {
  it("returns a usable document", async () => {
    const discovery = new OidcDiscovery(fetchReturning(document()), movableClock());

    await expect(discovery.load(ISSUER)).resolves.toMatchObject({
      token_endpoint: `${ISSUER}/token`,
    });
  });

  it("refuses a document that names another issuer", async () => {
    // THE security assertion. The document says where to send the user and
    // where to fetch signing keys, so a substituted one is a complete
    // takeover: authorization to an attacker's page, jwks_uri to keys they
    // control, and every signature check downstream passes.
    const discovery = new OidcDiscovery(
      fetchReturning(document({ issuer: "https://evil.example" })),
      movableClock(),
    );

    await expect(discovery.load(ISSUER)).rejects.toMatchObject({
      reason: "issuer_mismatch",
    });
  });

  it("compares the issuer exactly rather than by host", async () => {
    // A document served from the right host for the wrong tenant is the
    // multi-tenant mix-up a host check would wave through.
    const discovery = new OidcDiscovery(
      fetchReturning(document({ issuer: `${ISSUER}/tenant/b` })),
      movableClock(),
    );

    await expect(discovery.load(ISSUER)).rejects.toMatchObject({
      reason: "issuer_mismatch",
    });
  });

  it("refuses an IdP that does not advertise S256", async () => {
    // Either it has no PKCE or it has only `plain`. Both mean the
    // protection this client is built around is absent, and finding out at
    // configuration time beats finding out as a rejected request.
    const discovery = new OidcDiscovery(
      fetchReturning(document({ code_challenge_methods_supported: ["plain"] })),
      movableClock(),
    );

    await expect(discovery.load(ISSUER)).rejects.toMatchObject({
      reason: "no_pkce",
    });
  });

  it("names the field that is missing", async () => {
    // "malformed document" sends the reader to the wrong place when one
    // field out of thirty is absent.
    const discovery = new OidcDiscovery(
      fetchReturning(document({ jwks_uri: undefined })),
      movableClock(),
    );

    await expect(discovery.load(ISSUER)).rejects.toThrow(/jwks_uri/);
  });

  it("rejects a body that is not an object", async () => {
    // An HTML error page served with a 200 parses as a string, and every
    // field lookup on it would be undefined.
    const discovery = new OidcDiscovery(fetchReturning("<html>maintenance</html>"), movableClock());

    await expect(discovery.load(ISSUER)).rejects.toMatchObject({
      reason: "malformed",
    });
  });

  it("reports an HTTP failure with its status", async () => {
    const discovery = new OidcDiscovery(fetchReturning(null, false, 503), movableClock());

    await expect(discovery.load(ISSUER)).rejects.toThrow(/503/);
  });

  it("serves the cache instead of fetching again", async () => {
    const fetch = fetchReturning(document());
    const discovery = new OidcDiscovery(fetch, movableClock());

    await discovery.load(ISSUER);
    await discovery.load(ISSUER);

    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it("refetches once the ttl has passed", async () => {
    // A key rotation should be picked up the same working day, not on the
    // next app launch.
    const fetch = fetchReturning(document());
    const clock = movableClock();
    const discovery = new OidcDiscovery(fetch, clock, { ttlSeconds: 60 });

    await discovery.load(ISSUER);
    clock.advance(61_000);
    await discovery.load(ISSUER);

    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it("makes one request when callers arrive together", async () => {
    // App start typically asks several times at once. Without this, a
    // cold cache means one request per caller.
    const fetch = fetchReturning(document());
    const discovery = new OidcDiscovery(fetch, movableClock());

    await Promise.all([discovery.load(ISSUER), discovery.load(ISSUER), discovery.load(ISSUER)]);

    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it("does not cache a failure", async () => {
    const failing = vi.fn(async () => ({
      ok: false,
      status: 500,
      json: async () => null,
    }));
    const discovery = new OidcDiscovery(failing, movableClock());

    await expect(discovery.load(ISSUER)).rejects.toBeInstanceOf(DiscoveryError);
    await expect(discovery.load(ISSUER)).rejects.toBeInstanceOf(DiscoveryError);

    expect(failing).toHaveBeenCalledTimes(2);
  });

  it("caches per issuer", async () => {
    const fetch = fetchReturning(document());
    const discovery = new OidcDiscovery(fetch, movableClock(), {
      requireS256: false,
    });

    await discovery.load(ISSUER);
    await discovery.load(ISSUER).catch(() => undefined);

    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it("can be told to forget a document", async () => {
    // After a signature failure, the cached jwks_uri is the first thing to
    // doubt.
    const fetch = fetchReturning(document());
    const discovery = new OidcDiscovery(fetch, movableClock());

    await discovery.load(ISSUER);
    discovery.forget(ISSUER);
    await discovery.load(ISSUER);

    expect(fetch).toHaveBeenCalledTimes(2);
  });
});
