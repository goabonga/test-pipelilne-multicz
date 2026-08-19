// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

import { describe, expect, it, vi } from "vitest";
import type { Clock } from "../../src/oidc/ports";
import { NoRefreshTokenError, needsRefresh, RefreshManager } from "../../src/oidc/refresh";
import type { Tokens } from "../../src/oidc/session";

const NOW = 1_760_000_000_000;

function clockAt(now: number): Clock {
  return { now: () => now };
}

function tokensExpiringIn(seconds: number, refreshToken = "r1"): Tokens {
  return {
    accessToken: "a1",
    refreshToken,
    expiresAt: NOW + seconds * 1000,
  };
}

/** A refresh that resolves only when the test says so. */
function deferredExchange() {
  let release!: (t: Tokens) => void;
  let reject!: (e: Error) => void;
  const calls: string[] = [];

  const exchange = vi.fn(async (refreshToken: string) => {
    calls.push(refreshToken);
    return new Promise<Tokens>((res, rej) => {
      release = res;
      reject = rej;
    });
  });

  return {
    exchange,
    calls,
    release: (t: Tokens) => release(t),
    reject: (e: Error) => reject(e),
  };
}

describe("needsRefresh", () => {
  it("is true inside the margin and false outside it", () => {
    const clock = clockAt(NOW);

    expect(needsRefresh(tokensExpiringIn(30), clock, 60)).toBe(true);
    expect(needsRefresh(tokensExpiringIn(300), clock, 60)).toBe(false);
  });

  it("is true for a token that already expired", () => {
    expect(needsRefresh(tokensExpiringIn(-10), clockAt(NOW), 60)).toBe(true);
  });

  it("compares against the injected clock, not the wall", () => {
    // Otherwise "does it refresh a minute early" is a test that waits a
    // minute, and nobody writes it.
    const tokens = tokensExpiringIn(120);

    expect(needsRefresh(tokens, clockAt(NOW), 60)).toBe(false);
    expect(needsRefresh(tokens, clockAt(NOW + 61_000), 60)).toBe(true);
  });
});

describe("RefreshManager", () => {
  it("spends exactly one refresh token when callers arrive together", async () => {
    // THE assertion in this file. Refresh tokens rotate: each use
    // invalidates the one presented. A second concurrent refresh presents
    // a token the first already spent, and a conforming IdP treats that
    // replay as theft and revokes the whole grant — signing the user out
    // because two screens mounted at once.
    const d = deferredExchange();
    const manager = new RefreshManager(d.exchange, clockAt(NOW));
    const tokens = tokensExpiringIn(10);

    const all = Promise.all([
      manager.refresh(tokens),
      manager.refresh(tokens),
      manager.refresh(tokens),
    ]);

    d.release(tokensExpiringIn(3600, "r2"));
    const results = await all;

    expect(d.exchange).toHaveBeenCalledTimes(1);
    expect(d.calls).toEqual(["r1"]);
    // Every caller gets the same result, so none of them is left holding
    // the token that was just invalidated.
    expect(results[0]).toBe(results[1]);
    expect(results[1]).toBe(results[2]);
  });

  it("allows a new refresh once the previous one finished", async () => {
    const d = deferredExchange();
    const manager = new RefreshManager(d.exchange, clockAt(NOW));

    const first = manager.refresh(tokensExpiringIn(10, "r1"));
    d.release(tokensExpiringIn(3600, "r2"));
    await first;

    const second = manager.refresh(tokensExpiringIn(10, "r2"));
    d.release(tokensExpiringIn(3600, "r3"));
    await second;

    expect(d.calls).toEqual(["r1", "r2"]);
  });

  it("does not cache a failure forever", async () => {
    // A rejected promise left in the slot would make one network blip
    // permanent: every later caller receives the same failure without ever
    // retrying, and the session dies from a hiccup.
    const d = deferredExchange();
    const manager = new RefreshManager(d.exchange, clockAt(NOW));

    const failing = manager.refresh(tokensExpiringIn(10));
    d.reject(new Error("network"));
    await expect(failing).rejects.toThrow("network");

    const retry = manager.refresh(tokensExpiringIn(10));
    d.release(tokensExpiringIn(3600, "r2"));

    await expect(retry).resolves.toMatchObject({ refreshToken: "r2" });
    expect(d.exchange).toHaveBeenCalledTimes(2);
  });

  it("shares a failure with everyone who joined it", async () => {
    const d = deferredExchange();
    const manager = new RefreshManager(d.exchange, clockAt(NOW));

    const a = manager.refresh(tokensExpiringIn(10));
    const b = manager.refresh(tokensExpiringIn(10));
    d.reject(new Error("revoked"));

    await expect(a).rejects.toThrow("revoked");
    await expect(b).rejects.toThrow("revoked");
    expect(d.exchange).toHaveBeenCalledTimes(1);
  });

  it("refuses a session with no refresh token", async () => {
    // Nothing to retry here — the only correct response is a fresh
    // authorization, so this throws rather than reporting a failed refresh
    // a caller might loop on.
    const manager = new RefreshManager(vi.fn(), clockAt(NOW));

    await expect(
      manager.refresh({ accessToken: "a", expiresAt: NOW + 1000 }),
    ).rejects.toBeInstanceOf(NoRefreshTokenError);
  });

  it("leaves a token alone while it is still fresh", async () => {
    const exchange = vi.fn();
    const manager = new RefreshManager(exchange, clockAt(NOW));
    const tokens = tokensExpiringIn(3600);

    await expect(manager.ensureFresh(tokens)).resolves.toBe(tokens);
    expect(exchange).not.toHaveBeenCalled();
  });

  it("renews before expiry rather than after a 401", async () => {
    // Waiting for a 401 means every request crossing the boundary fails
    // once and is retried — a stall for the user and a burst of
    // unauthorised requests for the server.
    const d = deferredExchange();
    const manager = new RefreshManager(d.exchange, clockAt(NOW));

    const pending = manager.ensureFresh(tokensExpiringIn(30));
    d.release(tokensExpiringIn(3600, "r2"));

    await expect(pending).resolves.toMatchObject({ refreshToken: "r2" });
  });

  it("honours a configured margin", async () => {
    const exchange = vi.fn();
    const manager = new RefreshManager(exchange, clockAt(NOW), {
      marginSeconds: 600,
    });

    expect(manager.needsRefresh(tokensExpiringIn(300))).toBe(true);
    expect(manager.needsRefresh(tokensExpiringIn(900))).toBe(false);
  });
});
