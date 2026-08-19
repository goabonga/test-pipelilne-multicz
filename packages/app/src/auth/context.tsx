// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * React bindings over ShomerClient.
 *
 * A thin layer on purpose. Everything decidable lives in the client, so
 * this file is subscription and re-render: the flow is already tested
 * without React, and a bug found here should be a bug about rendering.
 *
 * WHY THE CLIENT IS NOT THE STATE
 *
 * ShomerClient holds its session in a private field, which React cannot
 * observe. Mirroring it into component state is what makes a sign-in
 * repaint anything — and the mirror has to be updated in one place, or
 * two screens disagree about whether the user is signed in.
 */

import type { IdTokenClaims, SessionState, Tokens } from "@shomer/lib";
import {
  createContext,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

import type { ShomerClient } from "./client";

interface ShomerContextValue {
  readonly state: SessionState;
  readonly signIn: () => Promise<IdTokenClaims | undefined>;
  readonly signOut: () => Promise<void>;
  /** True until the stored session has been read back on first mount. */
  readonly restoring: boolean;
}

const ShomerContext = createContext<ShomerContextValue | undefined>(undefined);

export interface ShomerProviderProps {
  readonly client: ShomerClient;
  readonly children: ReactNode;
}

export function ShomerProvider({ client, children }: ShomerProviderProps) {
  const [state, setState] = useState<SessionState>(client.state);

  // TRUE BEFORE THE FIRST RENDER, not after an effect has run. A provider
  // that starts at false shows the signed-out screen for one frame on
  // every launch, then replaces it — which reads as a logout flicker to a
  // user who never logged out.
  const [restoring, setRestoring] = useState(true);

  useEffect(() => {
    let cancelled = false;

    void client
      .restore()
      .catch(() => undefined)
      .finally(() => {
        // Guarded because a provider can unmount before storage answers —
        // a fast sign-out, or a navigator swapping the tree. Setting state
        // then is a warning in development and a leak in principle.
        if (!cancelled) {
          setState(client.state);
          setRestoring(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [client]);

  const signIn = useCallback(async () => {
    try {
      return await client.signIn();
    } finally {
      // In `finally` rather than after the call: a rejected sign-in also
      // moves the session — to `expired` — and a component that never saw
      // that change would keep showing a spinner for a flow that ended.
      setState(client.state);
    }
  }, [client]);

  const signOut = useCallback(async () => {
    try {
      await client.signOut();
    } finally {
      setState(client.state);
    }
  }, [client]);

  const value = useMemo(
    () => ({ state, signIn, signOut, restoring }),
    [state, signIn, signOut, restoring],
  );

  return <ShomerContext.Provider value={value}>{children}</ShomerContext.Provider>;
}

function useShomerContext(hook: string): ShomerContextValue {
  const context = useContext(ShomerContext);
  if (!context) {
    // Named, because the default failure is a null dereference several
    // frames deep with nothing pointing at the missing provider.
    throw new Error(`${hook} must be used inside a <ShomerProvider>`);
  }
  return context;
}

/** The whole session, for a component that renders on any change. */
export function useAuth(): ShomerContextValue {
  return useShomerContext("useAuth");
}

/**
 * The session state alone.
 *
 * Separate from useAuth so a component that only branches on "signed in or
 * not" does not also re-render when the callbacks are recreated.
 */
export function useSession(): {
  readonly state: SessionState;
  readonly restoring: boolean;
} {
  const { state, restoring } = useShomerContext("useSession");
  return useMemo(() => ({ state, restoring }), [state, restoring]);
}

/**
 * The current access token, or undefined.
 *
 * DELIBERATELY NOT ASYNC AND DELIBERATELY NOT REFRESHING. A hook that
 * refreshed on read would fire once per component that calls it, on every
 * render — which is the concurrent-refresh problem RefreshManager exists
 * to prevent, reintroduced one component at a time.
 *
 * Refreshing belongs to whatever makes the request; this reports what is
 * held right now.
 */
export function useAccessToken(): string | undefined {
  const { state } = useShomerContext("useAccessToken");

  const tokens: Tokens | undefined =
    state.status === "authenticated" || state.status === "refreshing" ? state.tokens : undefined;

  return tokens?.accessToken;
}
