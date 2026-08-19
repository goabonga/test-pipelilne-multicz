// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * OIDC discovery — fetching and caching the well-known document.
 *
 * WHY DISCOVERY RATHER THAN CONFIGURED ENDPOINTS
 *
 * The plan targets Pro Santé Connect and FranceConnect, and an IdP is
 * free to move its endpoints or rotate its JWKS URL. Hard-coding them
 * means a config change on their side becomes an app release on ours —
 * which for a mobile app is days, through a store review.
 *
 * THE ISSUER CHECK IS THE SECURITY CONTROL HERE.
 *
 * The document says where to send the user and where to fetch signing
 * keys. A substituted document is therefore a complete takeover: it can
 * point authorization at an attacker's page and jwks_uri at keys they
 * control, and every signature check downstream would pass.
 *
 * TLS is what stops the substitution, and it is the caller's Fetch that
 * provides it. What this module adds is the check TLS cannot make: that
 * the document describes the issuer we asked for. OIDC Discovery §4.3
 * requires `issuer` to match the one used to build the request, and a
 * mismatch means the response came from somewhere else — a redirect, a
 * misconfigured proxy, a cache serving another tenant.
 */

import type { Clock } from "./ports";

/** Just enough of the document to run the flow. IdPs publish far more. */
export interface OidcConfiguration {
  readonly issuer: string;
  readonly authorization_endpoint: string;
  readonly token_endpoint: string;
  readonly jwks_uri: string;
  readonly end_session_endpoint?: string;
  readonly userinfo_endpoint?: string;
  readonly revocation_endpoint?: string;
  readonly code_challenge_methods_supported?: readonly string[];
  readonly [key: string]: unknown;
}

/** Injected: this package cannot reach for `fetch`, which is a DOM global. */
export type Fetch = (url: string) => Promise<{
  readonly ok: boolean;
  readonly status: number;
  json(): Promise<unknown>;
}>;

export class DiscoveryError extends Error {
  constructor(
    message: string,
    readonly reason: "http" | "malformed" | "issuer_mismatch" | "no_pkce",
  ) {
    super(message);
    this.name = "DiscoveryError";
  }
}

export interface DiscoveryOptions {
  /**
   * How long a fetched document stays usable.
   *
   * An hour by default. Long enough that discovery is not a per-login
   * round trip; short enough that a key rotation is picked up the same
   * working day rather than on the next app launch.
   */
  readonly ttlSeconds?: number;
  /**
   * Refuse an IdP that does not advertise S256.
   *
   * On by default. An IdP without it either does not support PKCE or
   * supports only `plain`, and both mean the protection this client is
   * built around is absent — which is worth failing loudly at
   * configuration time rather than discovering as a rejected request.
   */
  readonly requireS256?: boolean;
}

const DEFAULT_TTL_SECONDS = 3600;

/** RFC 8414: the path is appended to the issuer, not to its origin. */
export function wellKnownUrl(issuer: string): string {
  // A trailing slash would produce a double slash, which some IdPs 404 on
  // — one of those failures that looks like the IdP being down.
  const base = issuer.endsWith("/") ? issuer.slice(0, -1) : issuer;
  return `${base}/.well-known/openid-configuration`;
}

function assertUsable(
  document: unknown,
  expectedIssuer: string,
  requireS256: boolean,
): OidcConfiguration {
  if (typeof document !== "object" || document === null) {
    throw new DiscoveryError("discovery document is not an object", "malformed");
  }

  const config = document as Record<string, unknown>;
  for (const field of ["issuer", "authorization_endpoint", "token_endpoint", "jwks_uri"]) {
    if (typeof config[field] !== "string" || config[field] === "") {
      // Named individually: "malformed document" sends the reader to the
      // wrong place when one field out of thirty is missing.
      throw new DiscoveryError(`discovery document has no usable "${field}"`, "malformed");
    }
  }

  // OIDC Discovery §4.3. Exact comparison, not a prefix or a host check: a
  // document served from the right host for the wrong issuer is exactly
  // the multi-tenant mix-up this catches.
  if (config.issuer !== expectedIssuer) {
    throw new DiscoveryError(
      `discovery document declares issuer ${String(config.issuer)}, expected ${expectedIssuer}`,
      "issuer_mismatch",
    );
  }

  if (requireS256) {
    const methods = config.code_challenge_methods_supported;
    if (!Array.isArray(methods) || !methods.includes("S256")) {
      throw new DiscoveryError(
        `${expectedIssuer} does not advertise S256; PKCE would be absent or downgraded to plain`,
        "no_pkce",
      );
    }
  }

  return config as unknown as OidcConfiguration;
}

interface CacheEntry {
  readonly config: OidcConfiguration;
  readonly expiresAt: number;
}

export class OidcDiscovery {
  readonly #fetch: Fetch;
  readonly #clock: Clock;
  readonly #ttlSeconds: number;
  readonly #requireS256: boolean;
  readonly #cache = new Map<string, CacheEntry>();
  /** In-flight fetches, for the same reason RefreshManager has one. */
  readonly #inFlight = new Map<string, Promise<OidcConfiguration>>();

  constructor(fetch: Fetch, clock: Clock, options: DiscoveryOptions = {}) {
    this.#fetch = fetch;
    this.#clock = clock;
    this.#ttlSeconds = options.ttlSeconds ?? DEFAULT_TTL_SECONDS;
    this.#requireS256 = options.requireS256 ?? true;
  }

  async load(issuer: string): Promise<OidcConfiguration> {
    const cached = this.#cache.get(issuer);
    if (cached && this.#clock.now() < cached.expiresAt) {
      return cached.config;
    }

    const running = this.#inFlight.get(issuer);
    if (running) {
      return running;
    }

    const flight = this.#fetchAndValidate(issuer).finally(() => {
      this.#inFlight.delete(issuer);
    });
    this.#inFlight.set(issuer, flight);
    return flight;
  }

  async #fetchAndValidate(issuer: string): Promise<OidcConfiguration> {
    const response = await this.#fetch(wellKnownUrl(issuer));

    if (!response.ok) {
      throw new DiscoveryError(`discovery for ${issuer} returned ${response.status}`, "http");
    }

    const config = assertUsable(await response.json(), issuer, this.#requireS256);

    this.#cache.set(issuer, {
      config,
      expiresAt: this.#clock.now() + this.#ttlSeconds * 1000,
    });

    return config;
  }

  /** Drop a cached document — after a signature failure, say. */
  forget(issuer: string): void {
    this.#cache.delete(issuer);
  }
}
