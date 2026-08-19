// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * ID token validation — OIDC Core §3.1.3.7.
 *
 * THE SIGNATURE IS NOT CHECKED HERE, and that separation is deliberate
 * rather than an omission. Verifying it needs the IdP's JWKS, key
 * rotation, and an algorithm allow-list — none of which belongs in a
 * package that must run identically on a device and in a browser. It is
 * injected as `JwtVerifier`.
 *
 * What is here is the half that is skipped most often: the claims. A
 * signature proves the IdP minted the token; it says nothing about whether
 * the token was minted for THIS client, THIS request, or recently. Every
 * check below closes one of those, and each has been a real vulnerability
 * in shipped clients:
 *
 *   iss   wrong issuer  — a token from an IdP we do not trust
 *   aud   wrong client  — a token minted for a different application,
 *                         which its owner can therefore replay against us
 *   exp   expired       — a token valid last year
 *   nonce wrong request — a token replayed from another session
 *
 * `azp` is checked when present, because a token with several audiences is
 * only for us if it says so.
 */

import type { Clock } from "./ports";

/**
 * Claims this module reads. An ID token carries more; the rest is left to
 * the caller rather than modelled here, since every IdP adds its own and a
 * closed shape would reject them.
 */
export interface IdTokenClaims {
  readonly iss: string;
  readonly sub: string;
  readonly aud: string | readonly string[];
  readonly exp: number;
  readonly iat: number;
  readonly nonce?: string;
  readonly azp?: string;
  readonly auth_time?: number;
  readonly acr?: string;
  readonly [claim: string]: unknown;
}

/** Verifies the signature and returns the claims. Injected — see above. */
export interface JwtVerifier {
  verify(token: string): Promise<IdTokenClaims>;
}

export interface IdTokenValidationParams {
  /** The issuer from the discovery document, compared exactly. */
  readonly issuer: string;
  readonly clientId: string;
  /** The nonce sent with the authorization request. */
  readonly nonce: string;
  /**
   * Seconds of tolerance for clock skew between this device and the IdP.
   *
   * Small on purpose. Every second here is a second an expired token stays
   * acceptable, and a device whose clock is minutes out has a problem this
   * should surface rather than paper over.
   */
  readonly clockToleranceSeconds?: number;
  /** Reject if the user authenticated longer ago than this. */
  readonly maxAgeSeconds?: number;
}

const DEFAULT_CLOCK_TOLERANCE_SECONDS = 60;

export class IdTokenValidationError extends Error {
  constructor(
    message: string,
    /** Machine-readable, so callers can branch without parsing prose. */
    readonly reason:
      | "issuer"
      | "audience"
      | "authorized_party"
      | "expired"
      | "issued_in_future"
      | "nonce"
      | "auth_time",
  ) {
    super(message);
    this.name = "IdTokenValidationError";
  }
}

/**
 * Verify the signature, then check every claim that binds the token to
 * this client and this request.
 *
 * Order matters: the signature comes first, because reading claims out of
 * an unverified token and acting on them is how a validator becomes a
 * parser for attacker-controlled input.
 */
export async function validateIdToken(
  token: string,
  params: IdTokenValidationParams,
  verifier: JwtVerifier,
  clock: Clock,
): Promise<IdTokenClaims> {
  const claims = await verifier.verify(token);

  if (claims.iss !== params.issuer) {
    throw new IdTokenValidationError(
      `token issued by ${claims.iss}, expected ${params.issuer}`,
      "issuer",
    );
  }

  // `aud` may be a string or an array. The array form is the interesting
  // one: a token listing several audiences is usable by each of them, so
  // being present is not the same as being the intended recipient — which
  // is what `azp` below settles.
  const audiences = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!audiences.includes(params.clientId)) {
    throw new IdTokenValidationError(
      `token audience ${audiences.join(", ")} does not include ${params.clientId}`,
      "audience",
    );
  }

  if (claims.azp !== undefined && claims.azp !== params.clientId) {
    throw new IdTokenValidationError(
      `token authorized for ${claims.azp}, not ${params.clientId}`,
      "authorized_party",
    );
  }

  const nowSeconds = Math.floor(clock.now() / 1000);
  const tolerance = params.clockToleranceSeconds ?? DEFAULT_CLOCK_TOLERANCE_SECONDS;

  if (nowSeconds - tolerance >= claims.exp) {
    throw new IdTokenValidationError(
      `token expired at ${claims.exp}, now ${nowSeconds}`,
      "expired",
    );
  }

  // A token issued in the future is not a clock problem to shrug at: it is
  // what a replayed or forged token looks like when the forger's clock is
  // wrong.
  if (claims.iat - tolerance > nowSeconds) {
    throw new IdTokenValidationError(
      `token issued at ${claims.iat}, which is in the future`,
      "issued_in_future",
    );
  }

  // Compared unconditionally. Treating an absent nonce as acceptable is
  // the bug: an attacker who can strip the claim would strip the check
  // with it.
  if (claims.nonce !== params.nonce) {
    throw new IdTokenValidationError(
      "token nonce does not match the authorization request",
      "nonce",
    );
  }

  if (params.maxAgeSeconds !== undefined) {
    if (claims.auth_time === undefined) {
      throw new IdTokenValidationError(
        "max_age was requested but the token carries no auth_time",
        "auth_time",
      );
    }
    if (nowSeconds - claims.auth_time > params.maxAgeSeconds + tolerance) {
      throw new IdTokenValidationError(
        `user authenticated ${nowSeconds - claims.auth_time}s ago, max_age is ${params.maxAgeSeconds}s`,
        "auth_time",
      );
    }
  }

  return claims;
}
