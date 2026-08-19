// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * The session state machine.
 *
 * WHY A MACHINE RATHER THAN A FEW BOOLEANS
 *
 * `isLoading`, `isAuthenticated` and `hasError` can be true at once, and
 * that combination has no meaning — but nothing stops a component setting
 * it, and every consumer then has to guess what it wants. States that
 * cannot be held simultaneously make the impossible ones unrepresentable
 * instead of merely discouraged.
 *
 * The transitions below are exhaustive: anything not listed is refused and
 * reported, rather than silently ignored. A refresh that completes after
 * the user signed out must not resurrect the session, and that is a
 * transition question rather than a race to be patched at the call site.
 */

export type SessionStatus = "idle" | "authorizing" | "authenticated" | "refreshing" | "expired";

export interface Tokens {
  readonly accessToken: string;
  readonly refreshToken?: string;
  readonly idToken?: string;
  /** Absolute, milliseconds since the epoch — never a duration. */
  readonly expiresAt: number;
}

export type SessionState =
  | { readonly status: "idle" }
  /** Holds what the callback will need to check itself against. */
  | {
      readonly status: "authorizing";
      readonly state: string;
      readonly nonce: string;
      readonly verifier: string;
    }
  | { readonly status: "authenticated"; readonly tokens: Tokens }
  /** Keeps the current tokens: a refresh in flight is not a signed-out user. */
  | { readonly status: "refreshing"; readonly tokens: Tokens }
  | { readonly status: "expired"; readonly reason: string };

export type SessionEvent =
  | {
      readonly type: "authorize";
      readonly state: string;
      readonly nonce: string;
      readonly verifier: string;
    }
  | { readonly type: "authorized"; readonly tokens: Tokens }
  | { readonly type: "refresh" }
  | { readonly type: "refreshed"; readonly tokens: Tokens }
  | { readonly type: "expire"; readonly reason: string }
  /**
   * Adopt tokens read back from storage on launch.
   *
   * A separate event rather than a replayed authorization, because
   * restoring is not authorizing: there is no state, no nonce and no
   * verifier to check, and inventing empty ones would put values into a
   * session that anything comparing against them would silently accept.
   *
   * The tokens are trusted only as far as storage is: they were validated
   * when they were written, and a caller that wants more should refresh
   * rather than re-run the whole flow.
   */
  | { readonly type: "restore"; readonly tokens: Tokens }
  | { readonly type: "signOut" };

export class InvalidTransitionError extends Error {
  constructor(
    readonly from: SessionStatus,
    readonly event: SessionEvent["type"],
  ) {
    super(`cannot ${event} while ${from}`);
    this.name = "InvalidTransitionError";
  }
}

/**
 * Apply an event. Pure: same state and event, same result, no side
 * effects — which is what lets the whole flow be tested without a network,
 * a browser or a device.
 *
 * Throws on a transition that is not allowed rather than returning the
 * state unchanged. Silently ignoring one hides the bug that produced it,
 * and the ones that matter here are precisely the ones that look harmless:
 * a late refresh landing after sign-out, a second authorize while one is
 * already in flight.
 */
export function transition(state: SessionState, event: SessionEvent): SessionState {
  // Always allowed, from anywhere, including `idle`. Signing out of a
  // session you do not have is not an error — it is what a user does when
  // they are unsure, and refusing it would make the safest action the one
  // that throws.
  if (event.type === "signOut") {
    return { status: "idle" };
  }

  switch (state.status) {
    case "idle":
      // Only from idle. A restore arriving mid-flow would replace a live
      // authorization with whatever was on disk before it started.
      if (event.type === "restore") {
        return { status: "authenticated", tokens: event.tokens };
      }
      if (event.type === "authorize") {
        return {
          status: "authorizing",
          state: event.state,
          nonce: event.nonce,
          verifier: event.verifier,
        };
      }
      break;

    case "authorizing":
      if (event.type === "authorized") {
        return { status: "authenticated", tokens: event.tokens };
      }
      // A failed or abandoned authorization ends here rather than looping
      // back to idle, so the caller can tell "never started" from "tried
      // and did not finish" — one deserves a retry, the other a message.
      if (event.type === "expire") {
        return { status: "expired", reason: event.reason };
      }
      break;

    case "authenticated":
      if (event.type === "refresh") {
        return { status: "refreshing", tokens: state.tokens };
      }
      if (event.type === "expire") {
        return { status: "expired", reason: event.reason };
      }
      break;

    case "refreshing":
      if (event.type === "refreshed") {
        return { status: "authenticated", tokens: event.tokens };
      }
      if (event.type === "expire") {
        return { status: "expired", reason: event.reason };
      }
      break;

    case "expired":
      // Only a fresh authorization leaves this state. `refresh` is
      // deliberately not accepted: the refresh token is what expired, and
      // retrying with it is the loop that hammers an IdP until it rate
      // limits the client.
      if (event.type === "authorize") {
        return {
          status: "authorizing",
          state: event.state,
          nonce: event.nonce,
          verifier: event.verifier,
        };
      }
      break;
  }

  throw new InvalidTransitionError(state.status, event.type);
}

/** Whether the caller currently holds usable tokens. */
export function tokensOf(state: SessionState): Tokens | undefined {
  return state.status === "authenticated" || state.status === "refreshing"
    ? state.tokens
    : undefined;
}
