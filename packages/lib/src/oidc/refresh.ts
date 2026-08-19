// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * Refreshing an access token before it expires.
 *
 * SINGLE-FLIGHT IS A CORRECTNESS REQUIREMENT HERE, NOT AN OPTIMISATION.
 *
 * The plan mandates rotating refresh tokens: each use invalidates the one
 * presented and returns a replacement. So two concurrent refreshes are not
 * merely wasteful — the second presents a token the first has already
 * spent, the IdP rejects it, and a conforming IdP treats a replayed
 * refresh token as theft and revokes the entire grant. The user is signed
 * out, and the trigger was two screens mounting at once.
 *
 * A screen full of components each noticing an expiring token is the
 * normal case, not an edge case. So concurrent callers share one in-flight
 * request and all receive its result.
 *
 * PROACTIVE, NOT REACTIVE. Waiting for a 401 means every request that
 * happens to cross the expiry boundary fails once and is retried, which is
 * visible to the user as a stall and to the server as a spike of
 * unauthorised requests. Refreshing on a margin avoids both.
 */

import type { Clock } from "./ports";
import type { Tokens } from "./session";

/** Exchanges a refresh token for a new set. Injected — it needs a network. */
export type RefreshTokenExchange = (refreshToken: string) => Promise<Tokens>;

export interface RefreshManagerOptions {
  /**
   * How long before expiry a token is treated as due for renewal.
   *
   * Sixty seconds by default: long enough to cover a slow round trip on a
   * hospital wifi, short enough that it does not throw away most of a
   * five-minute token's life.
   */
  readonly marginSeconds?: number;
}

const DEFAULT_MARGIN_SECONDS = 60;

export class NoRefreshTokenError extends Error {
  constructor() {
    super("the session has no refresh token");
    this.name = "NoRefreshTokenError";
  }
}

/**
 * Whether these tokens should be renewed now.
 *
 * Compared against the injected clock rather than Date.now(), so "does it
 * refresh a minute early" is a test that runs instantly instead of one
 * that waits.
 */
export function needsRefresh(
  tokens: Tokens,
  clock: Clock,
  marginSeconds: number = DEFAULT_MARGIN_SECONDS,
): boolean {
  return clock.now() >= tokens.expiresAt - marginSeconds * 1000;
}

export class RefreshManager {
  readonly #exchange: RefreshTokenExchange;
  readonly #clock: Clock;
  readonly #marginSeconds: number;

  /**
   * The request currently in flight, if any. This field IS the
   * single-flight guarantee: everything else is bookkeeping around it.
   */
  #inFlight?: Promise<Tokens>;

  constructor(exchange: RefreshTokenExchange, clock: Clock, options: RefreshManagerOptions = {}) {
    this.#exchange = exchange;
    this.#clock = clock;
    this.#marginSeconds = options.marginSeconds ?? DEFAULT_MARGIN_SECONDS;
  }

  /** Whether these tokens are due for renewal, per the configured margin. */
  needsRefresh(tokens: Tokens): boolean {
    return needsRefresh(tokens, this.#clock, this.#marginSeconds);
  }

  /**
   * Refresh, or join the refresh already running.
   *
   * Callers that arrive while one is in flight get the same promise, so
   * exactly one refresh token is ever spent per rotation.
   */
  async refresh(tokens: Tokens): Promise<Tokens> {
    if (this.#inFlight) {
      return this.#inFlight;
    }

    if (!tokens.refreshToken) {
      // Thrown rather than returned as a failed refresh: there is nothing
      // to retry, and the only correct response is a fresh authorization.
      throw new NoRefreshTokenError();
    }

    // Assigned before the first await so that a caller arriving in the
    // same tick sees it. Building the promise and assigning it afterwards
    // would leave a window in which two callers both start a request —
    // which is the exact failure this class exists to prevent.
    const flight = this.#exchange(tokens.refreshToken).finally(() => {
      // Cleared whether it resolved or rejected. Leaving a rejected
      // promise cached would make one network blip permanent: every later
      // caller would receive the same failure without retrying.
      this.#inFlight = undefined;
    });

    this.#inFlight = flight;
    return flight;
  }

  /**
   * Refresh only if the margin has been reached, otherwise hand back what
   * was passed in.
   */
  async ensureFresh(tokens: Tokens): Promise<Tokens> {
    return this.needsRefresh(tokens) ? this.refresh(tokens) : tokens;
  }
}
