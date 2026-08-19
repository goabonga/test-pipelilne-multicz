// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

import { describe, expect, it } from "vitest";

import {
  InvalidTransitionError,
  type SessionEvent,
  type SessionState,
  type Tokens,
  tokensOf,
  transition,
} from "../../src/oidc/session";

const tokens: Tokens = {
  accessToken: "access",
  refreshToken: "refresh",
  expiresAt: 1_760_000_000_000,
};

const authorize: SessionEvent = {
  type: "authorize",
  state: "st",
  nonce: "no",
  verifier: "ve",
};

const idle: SessionState = { status: "idle" };
const authorizing = transition(idle, authorize);
const authenticated = transition(authorizing, { type: "authorized", tokens });
const refreshing = transition(authenticated, { type: "refresh" });
const expired = transition(authenticated, {
  type: "expire",
  reason: "refresh token rejected",
});

describe("transition", () => {
  it("walks the whole happy path", () => {
    expect(authorizing.status).toBe("authorizing");
    expect(authenticated.status).toBe("authenticated");
    expect(refreshing.status).toBe("refreshing");
    expect(transition(refreshing, { type: "refreshed", tokens }).status).toBe("authenticated");
  });

  it("keeps what the callback will need to check itself against", () => {
    // state and nonce are compared when the browser returns, and the
    // verifier is presented at the token exchange. Losing any of them
    // means the callback cannot be validated and the flow must restart.
    expect(authorizing).toMatchObject({
      state: "st",
      nonce: "no",
      verifier: "ve",
    });
  });

  it("keeps the current tokens while refreshing", () => {
    // A refresh in flight is not a signed-out user. Dropping the tokens
    // here would log the user out for the duration of every refresh,
    // which is the visible half of a very common bug.
    expect(tokensOf(refreshing)).toEqual(tokens);
  });

  it("reports no tokens when there are none", () => {
    expect(tokensOf(idle)).toBeUndefined();
    expect(tokensOf(expired)).toBeUndefined();
  });

  it("refuses a second authorize while one is in flight", () => {
    // Two concurrent authorizations mean two state values, and the
    // callback can only match one — so the other silently fails a check
    // it should have passed.
    expect(() => transition(authorizing, authorize)).toThrow(InvalidTransitionError);
  });

  it("refuses to resurrect a session after sign-out", () => {
    // THE assertion. A refresh started before sign-out can land after it.
    // Accepting the result would sign the user back in, having asked
    // nobody — and it is a transition question rather than a race to be
    // patched at each call site.
    const signedOut = transition(refreshing, { type: "signOut" });

    expect(signedOut.status).toBe("idle");
    expect(() => transition(signedOut, { type: "refreshed", tokens })).toThrow(
      InvalidTransitionError,
    );
  });

  it("expires when the refresh itself fails", () => {
    // The path that actually happens in production: a rotating refresh
    // token that the IdP has revoked. Without this transition the session
    // would sit in `refreshing` forever, showing a spinner for a session
    // that is already gone.
    const failed = transition(refreshing, {
      type: "expire",
      reason: "refresh token revoked",
    });

    expect(failed).toEqual({
      status: "expired",
      reason: "refresh token revoked",
    });
    expect(tokensOf(failed)).toBeUndefined();
  });

  it("refuses to refresh an expired session", () => {
    // The refresh token is what expired. Retrying with it is the loop that
    // hammers an IdP until it rate limits the client.
    expect(() => transition(expired, { type: "refresh" })).toThrow(InvalidTransitionError);
  });

  it("lets a fresh authorization leave the expired state", () => {
    expect(transition(expired, authorize).status).toBe("authorizing");
  });

  it("distinguishes never-started from tried-and-failed", () => {
    // One deserves a retry button, the other an explanation. Collapsing an
    // abandoned authorization back to idle loses that.
    const abandoned = transition(authorizing, {
      type: "expire",
      reason: "user cancelled",
    });

    expect(abandoned).toEqual({ status: "expired", reason: "user cancelled" });
  });

  it("allows signing out of a session that does not exist", () => {
    // Refusing it would make the safest action the one that throws.
    expect(transition(idle, { type: "signOut" }).status).toBe("idle");
  });

  it("refuses a second callback for a session already established", () => {
    // A deep link can be delivered twice — a double tap on the redirect, a
    // replayed universal link, an OS that re-opens the last intent. The
    // second delivery carries a code that was already exchanged, and
    // accepting it would replace a live session with the result of
    // redeeming a spent code.
    expect(() => transition(authenticated, { type: "authorized", tokens })).toThrow(
      InvalidTransitionError,
    );
  });

  it("refuses to start a login while a refresh is in flight", () => {
    // Both would race to write the session, and whichever lost would
    // leave its state and nonce stranded — so the callback it eventually
    // receives fails a check it should have passed.
    expect(() => transition(refreshing, authorize)).toThrow(InvalidTransitionError);
  });

  it("names both sides of a refused transition", () => {
    const error = (() => {
      try {
        transition(idle, { type: "refresh" });
      } catch (e: unknown) {
        return e as InvalidTransitionError;
      }
      throw new Error("expected a throw");
    })();

    expect(error.from).toBe("idle");
    expect(error.event).toBe("refresh");
    expect(error.message).toBe("cannot refresh while idle");
  });

  it("never mutates the state it was given", () => {
    // Callers hold on to previous states — React keeps the last render's.
    // A machine that mutated in place would change history under them.
    const before = { ...authenticated };
    transition(authenticated, { type: "refresh" });

    expect(authenticated).toEqual(before);
  });
});
