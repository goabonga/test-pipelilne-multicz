// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

import type { SessionState, Tokens } from "@shomer/lib";
import { act, create } from "react-test-renderer";

import type { ShomerClient } from "../auth/client";
import { ShomerProvider, useAccessToken, useAuth, useSession } from "../auth/context";

const tokens: Tokens = {
  accessToken: "the-access-token",
  expiresAt: 1_760_000_000_000,
};

/**
 * A stand-in for ShomerClient. Only the surface the provider touches, so
 * these tests are about rendering rather than about the flow — which is
 * already covered without React.
 */
function fakeClient(overrides: Partial<ShomerClient> = {}) {
  let state: SessionState = { status: "idle" };

  const client = {
    get state() {
      return state;
    },
    async restore() {
      state = { status: "authenticated", tokens };
      return tokens;
    },
    async signIn() {
      state = { status: "authenticated", tokens };
      return undefined;
    },
    async signOut() {
      state = { status: "idle" };
    },
    ...overrides,
  } as unknown as ShomerClient;

  return client;
}

/** Renders a hook and exposes whatever it returned. */
function renderHook<T>(useHook: () => T, client: ShomerClient) {
  const seen: T[] = [];

  function Probe() {
    seen.push(useHook());
    return null;
  }

  let tree!: ReturnType<typeof create>;
  act(() => {
    tree = create(
      <ShomerProvider client={client}>
        <Probe />
      </ShomerProvider>,
    );
  });

  return { seen, latest: () => seen[seen.length - 1] as T, tree };
}

describe("ShomerProvider", () => {
  it("starts as restoring before storage has answered", () => {
    // A provider that starts at false shows the signed-out screen for one
    // frame on every launch, then replaces it — which reads as a logout
    // flicker to a user who never logged out.
    const never = fakeClient({
      restore: () => new Promise(() => undefined),
    } as Partial<ShomerClient>);

    const { latest } = renderHook(() => useSession(), never);

    expect(latest().restoring).toBe(true);
    expect(latest().state.status).toBe("idle");
  });

  it("reports the restored session and stops restoring", async () => {
    const client = fakeClient();
    const { latest } = renderHook(() => useSession(), client);

    await act(async () => undefined);

    expect(latest().restoring).toBe(false);
    expect(latest().state.status).toBe("authenticated");
  });

  it("stops restoring even when storage fails", async () => {
    // Otherwise a corrupt keychain entry leaves the app on its splash
    // screen forever, with no error and nothing to retry.
    const failing = fakeClient({
      restore: async () => {
        throw new Error("keychain locked");
      },
    } as Partial<ShomerClient>);

    const { latest } = renderHook(() => useSession(), failing);
    await act(async () => undefined);

    expect(latest().restoring).toBe(false);
  });

  it("re-renders after a sign-in", async () => {
    const client = fakeClient({ restore: async () => undefined } as Partial<ShomerClient>);
    const { latest } = renderHook(() => useAuth(), client);
    await act(async () => undefined);

    await act(async () => {
      await latest().signIn();
    });

    expect(latest().state.status).toBe("authenticated");
  });

  it("re-renders after a sign-in that failed", async () => {
    // A rejected sign-in also moves the session — to expired — and a
    // component that never saw that change keeps showing a spinner for a
    // flow that has ended.
    let state: SessionState = { status: "idle" };
    const client = {
      get state() {
        return state;
      },
      restore: async () => undefined,
      signIn: async () => {
        state = { status: "expired", reason: "user dismissed" };
        throw new Error("cancelled");
      },
      signOut: async () => undefined,
    } as unknown as ShomerClient;

    const { latest } = renderHook(() => useAuth(), client);
    await act(async () => undefined);

    await act(async () => {
      await latest()
        .signIn()
        .catch(() => undefined);
    });

    expect(latest().state.status).toBe("expired");
  });

  it("re-renders after a sign-out", async () => {
    const client = fakeClient();
    const { latest } = renderHook(() => useAuth(), client);
    await act(async () => undefined);

    await act(async () => {
      await latest().signOut();
    });

    expect(latest().state.status).toBe("idle");
  });

  it("does not set state after unmounting", async () => {
    // A provider can unmount before storage answers — a fast sign-out, or
    // a navigator swapping the tree. Setting state then is a development
    // warning and a leak in principle.
    let release!: () => void;
    const slow = fakeClient({
      restore: () =>
        new Promise((resolve) => {
          release = () => resolve(undefined);
        }),
    } as Partial<ShomerClient>);

    const { tree } = renderHook(() => useSession(), slow);
    act(() => {
      tree.unmount();
    });

    const warn = jest.spyOn(console, "error").mockImplementation(() => undefined);
    await act(async () => {
      release();
    });

    expect(warn).not.toHaveBeenCalled();
    warn.mockRestore();
  });
});

describe("useAccessToken", () => {
  it("reports the token while authenticated", async () => {
    const { latest } = renderHook(() => useAccessToken(), fakeClient());
    await act(async () => undefined);

    expect(latest()).toBe("the-access-token");
  });

  it("keeps reporting it during a refresh", async () => {
    // A refresh in flight is not a signed-out user, and a hook that
    // returned undefined here would make every screen flash its
    // signed-out state on each renewal.
    const refreshing = fakeClient({
      restore: async () => {
        return tokens;
      },
    } as Partial<ShomerClient>);
    Object.defineProperty(refreshing, "state", {
      get: () => ({ status: "refreshing", tokens }) as SessionState,
    });

    const { latest } = renderHook(() => useAccessToken(), refreshing);
    await act(async () => undefined);

    expect(latest()).toBe("the-access-token");
  });

  it("reports nothing when signed out", () => {
    const idle = fakeClient({
      restore: () => new Promise(() => undefined),
    } as Partial<ShomerClient>);

    const { latest } = renderHook(() => useAccessToken(), idle);

    expect(latest()).toBeUndefined();
  });
});

describe("the hooks outside a provider", () => {
  it.each([
    ["useAuth", useAuth],
    ["useSession", useSession],
    ["useAccessToken", useAccessToken],
  ])("%s names itself rather than dereferencing null", (name, hook) => {
    function Probe() {
      hook();
      return null;
    }

    const warn = jest.spyOn(console, "error").mockImplementation(() => undefined);
    expect(() => {
      act(() => {
        create(<Probe />);
      });
    }).toThrow(new RegExp(`${name} must be used inside`));
    warn.mockRestore();
  });
});
