// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * The authorization request — the URL the system browser is sent to.
 *
 * WHAT `state` AND `nonce` EACH DEFEND, because they are routinely
 * confused and only one of them is checked by most implementations.
 *
 *   state  is checked when the browser comes back. It ties the callback to
 *          the request this client started, which is what stops an
 *          attacker from feeding us a code obtained in their own session
 *          — a login CSRF that ends with the victim signed in as the
 *          attacker.
 *
 *   nonce  is carried inside the ID token and checked after the exchange.
 *          It ties the token to this request, which is what stops an ID
 *          token minted for another session being replayed at us.
 *
 * They are separate values on purpose. Reusing one for both means a leak
 * of the callback URL — a referrer header, a shoulder, a log — hands over
 * the token binding as well.
 */

import type { PkcePair } from "./pkce";
import { base64UrlEncode } from "./pkce";
import type { Crypto } from "./ports";

/** Bytes of entropy behind `state` and `nonce`. */
const NONCE_BYTES = 32;

export interface AuthorizationRequestParams {
  /** From the IdP's discovery document. */
  readonly authorizationEndpoint: string;
  readonly clientId: string;
  /**
   * Must match one registered with the IdP exactly, including the
   * trailing slash. A mismatch is rejected at the IdP with an error that
   * names neither value.
   */
  readonly redirectUri: string;
  /**
   * `openid` is required by the spec and added if absent — without it the
   * IdP runs a plain OAuth2 flow and returns no ID token, which fails much
   * later as a missing claim.
   */
  readonly scopes: readonly string[];
  readonly pkce: PkcePair;
  /**
   * Authentication Context Class Reference. Pro Santé Connect uses it to
   * demand a specific assurance level — the card, or a strong two-factor
   * path — and an IdP that receives none is free to satisfy the request
   * with whatever it already has.
   */
  readonly acrValues?: readonly string[];
  /**
   * `login` forces re-authentication, `none` requires an existing session
   * and fails otherwise. Left unset the IdP decides, which is right for an
   * ordinary sign-in and wrong for a step-up.
   */
  readonly prompt?: "none" | "login" | "consent" | "select_account";
  /** Seconds. The IdP re-authenticates if its session is older. */
  readonly maxAge?: number;
  /** Extra parameters an IdP requires that this interface does not model. */
  readonly extra?: Readonly<Record<string, string>>;
}

export interface AuthorizationRequest {
  /** Where to send the system browser. */
  readonly url: string;
  /** Kept until the callback returns, then compared. */
  readonly state: string;
  /** Kept until the ID token is validated, then compared. */
  readonly nonce: string;
}

function randomToken(crypto: Crypto): string {
  return base64UrlEncode(crypto.getRandomValues(new Uint8Array(NONCE_BYTES)));
}

/**
 * Build the authorization URL, and the two values that have to survive
 * until the browser comes back.
 *
 * The caller is responsible for storing `state` and `nonce` somewhere that
 * outlives the redirect and for comparing them on return. This function
 * cannot do it: on React Native the app may be evicted while the system
 * browser is in front, so the only safe place is storage the caller owns.
 */
export function createAuthorizationRequest(
  params: AuthorizationRequestParams,
  crypto: Crypto,
): AuthorizationRequest {
  const state = randomToken(crypto);
  const nonce = randomToken(crypto);

  const scopes = params.scopes.includes("openid") ? params.scopes : ["openid", ...params.scopes];

  const query: Record<string, string> = {
    response_type: "code",
    client_id: params.clientId,
    redirect_uri: params.redirectUri,
    scope: scopes.join(" "),
    state,
    nonce,
    code_challenge: params.pkce.challenge,
    code_challenge_method: params.pkce.method,
  };

  if (params.acrValues?.length) {
    query.acr_values = params.acrValues.join(" ");
  }
  if (params.prompt) {
    query.prompt = params.prompt;
  }
  if (params.maxAge !== undefined) {
    query.max_age = String(params.maxAge);
  }

  // Extras last, and deliberately unable to overwrite anything above: an
  // IdP-specific parameter that silently replaced `code_challenge` or
  // `redirect_uri` would disable PKCE or redirect elsewhere, and the
  // request would still look well-formed.
  for (const [key, value] of Object.entries(params.extra ?? {})) {
    if (key in query) {
      throw new Error(`extra parameter "${key}" would overwrite a protocol parameter`);
    }
    query[key] = value;
  }

  // Built by hand rather than with URL/URLSearchParams, and not only
  // because those are DOM globals this package must not reach for. React
  // Native ships a partial URL polyfill whose searchParams support has
  // been unreliable — so the same code would produce a correct URL in a
  // browser and a silently wrong one on a device, which is the worst
  // shape a portability bug can take.
  //
  // encodeURIComponent is the right encoder here: it escapes the
  // characters that matter in a query value, including the spaces that
  // separate scopes and acr_values.
  const query_string = Object.entries(query)
    .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(value)}`)
    .join("&");

  // An endpoint may legitimately already carry parameters — some IdPs
  // publish one with a tenant id baked in.
  const separator = params.authorizationEndpoint.includes("?") ? "&" : "?";

  return {
    url: `${params.authorizationEndpoint}${separator}${query_string}`,
    state,
    nonce,
  };
}
