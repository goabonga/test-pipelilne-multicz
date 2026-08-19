// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * The flow, assembled.
 *
 * Everything here is the ordering the pieces have to be used in — and the
 * ordering is where authentication clients go wrong, because each step
 * looks reasonable on its own.
 *
 * Deliberately not React. The hooks in ./hooks are a thin layer over this,
 * so the sequence can be tested without rendering anything, and so a
 * background refresh does not have to pretend to be a component.
 */

import {
  type AuthorizationRequest,
  type Browser,
  type Clock,
  type Crypto,
  createAuthorizationRequest,
  createPkcePair,
  type IdTokenClaims,
  type JwtVerifier,
  type OidcConfiguration,
  type SessionState,
  type TokenStorage,
  type Tokens,
  transition,
  validateIdToken,
} from "@shomer/lib";

import { isExpectedCallback, parseCallback } from "./system-browser";

export interface TokenExchange {
  /** Redeems the authorization code. Needs the verifier, never the challenge. */
  exchangeCode(input: {
    readonly code: string;
    readonly verifier: string;
    readonly redirectUri: string;
  }): Promise<{ readonly tokens: Tokens; readonly idToken?: string }>;
}

export interface ShomerClientOptions {
  readonly configuration: OidcConfiguration;
  readonly clientId: string;
  readonly redirectUri: string;
  readonly scopes: readonly string[];
  readonly acrValues?: readonly string[];
}

export class AuthorizationError extends Error {
  constructor(
    message: string,
    readonly reason:
      | "cancelled"
      | "idp_error"
      | "state_mismatch"
      | "unexpected_callback"
      | "no_code",
  ) {
    super(message);
    this.name = "AuthorizationError";
  }
}

export interface ShomerClientDeps {
  readonly browser: Browser;
  readonly storage: TokenStorage;
  readonly crypto: Crypto;
  readonly clock: Clock;
  readonly verifier: JwtVerifier;
  readonly exchange: TokenExchange;
}

export class ShomerClient {
  #state: SessionState = { status: "idle" };

  readonly #options: ShomerClientOptions;
  readonly #deps: ShomerClientDeps;

  constructor(options: ShomerClientOptions, deps: ShomerClientDeps) {
    this.#options = options;
    this.#deps = deps;
  }

  get state(): SessionState {
    return this.#state;
  }

  /**
   * Run a full authorization: build the request, open the browser, check
   * what came back, redeem the code, validate the token.
   */
  async signIn(): Promise<IdTokenClaims | undefined> {
    const pkce = await createPkcePair(this.#deps.crypto);
    const request: AuthorizationRequest = createAuthorizationRequest(
      {
        authorizationEndpoint: this.#options.configuration.authorization_endpoint,
        clientId: this.#options.clientId,
        redirectUri: this.#options.redirectUri,
        scopes: this.#options.scopes,
        acrValues: this.#options.acrValues,
        pkce,
      },
      this.#deps.crypto,
    );

    // Recorded BEFORE the browser opens. On React Native the app can be
    // evicted while the system browser is in front, and a state held only
    // in a local would be gone when the callback arrives — so the flow
    // would fail its own check for a reason indistinguishable from an
    // attack.
    this.#state = transition(this.#state, {
      type: "authorize",
      state: request.state,
      nonce: request.nonce,
      verifier: pkce.verifier,
    });

    const callbackUrl = await this.#deps.browser.open(request.url, this.#options.redirectUri);

    if (callbackUrl === undefined) {
      this.#state = transition(this.#state, {
        type: "expire",
        reason: "the user dismissed the sign-in",
      });
      throw new AuthorizationError("sign-in was dismissed", "cancelled");
    }

    return this.#completeSignIn(callbackUrl, request, pkce.verifier);
  }

  async #completeSignIn(
    callbackUrl: string,
    request: AuthorizationRequest,
    verifier: string,
  ): Promise<IdTokenClaims | undefined> {
    // Checked before anything is read out of it. A URL that is not our
    // redirect is not a callback at all, and parsing it first would mean
    // acting on attacker-chosen parameters.
    if (!isExpectedCallback(callbackUrl, this.#options.redirectUri)) {
      this.#fail("callback did not match the redirect", "unexpected_callback");
    }

    const params = parseCallback(callbackUrl);

    // The IdP's own refusal comes back this way — consent declined, or an
    // acr_values the account cannot satisfy. Reported before the state
    // check so the user sees why rather than a generic mismatch.
    if (params.error) {
      this.#fail(params.errorDescription ?? params.error, "idp_error");
    }

    // COMPARED AGAINST THE STORED STATE, not against the one in `request`.
    // They are the same value today; reading it from the session is what
    // keeps this correct when the app was evicted and rehydrated, which is
    // the case the check exists for.
    const expected = this.#state.status === "authorizing" ? this.#state.state : undefined;
    if (!params.state || params.state !== expected) {
      this.#fail("callback state did not match the request", "state_mismatch");
    }

    if (!params.code) {
      this.#fail("callback carried no authorization code", "no_code");
    }

    const { tokens, idToken } = await this.#deps.exchange.exchangeCode({
      code: params.code as string,
      verifier,
      redirectUri: this.#options.redirectUri,
    });

    let claims: IdTokenClaims | undefined;
    if (idToken) {
      claims = await validateIdToken(
        idToken,
        {
          issuer: this.#options.configuration.issuer,
          clientId: this.#options.clientId,
          nonce: request.nonce,
        },
        this.#deps.verifier,
        this.#deps.clock,
      );
    }

    // Persisted only after every check passed. Storing first and
    // validating after leaves a rejected token on the device, which the
    // next launch reads back and trusts.
    await this.#deps.storage.save(JSON.stringify(tokens));
    this.#state = transition(this.#state, { type: "authorized", tokens });

    return claims;
  }

  /** Ends the session locally and clears storage. */
  async signOut(): Promise<void> {
    this.#state = transition(this.#state, { type: "signOut" });
    // Cleared after the transition, so a storage failure cannot leave the
    // app believing it is still signed in.
    await this.#deps.storage.clear();
  }

  /** Restore a session written by a previous launch. */
  async restore(): Promise<Tokens | undefined> {
    const raw = await this.#deps.storage.load();
    if (!raw) {
      return undefined;
    }

    let tokens: Tokens;
    try {
      tokens = JSON.parse(raw) as Tokens;
    } catch {
      // Unreadable storage is treated as no session rather than as a
      // crash on launch. It is also cleared: leaving it would make every
      // future launch fail the same way.
      await this.#deps.storage.clear();
      return undefined;
    }

    // A first-class transition rather than a replayed authorization.
    // Faking a state, nonce and verifier to reach `authenticated` would
    // put empty strings into the session, and anything comparing against
    // them later would accept an empty match.
    this.#state = transition(this.#state, { type: "restore", tokens });
    return tokens;
  }

  #fail(message: string, reason: AuthorizationError["reason"]): never {
    this.#state = transition(this.#state, { type: "expire", reason: message });
    throw new AuthorizationError(message, reason);
  }
}
