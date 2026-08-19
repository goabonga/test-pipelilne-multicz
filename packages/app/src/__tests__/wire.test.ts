// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

import type { OidcConfiguration } from "@shomer/lib";

import * as auth from "../auth";
import type { NativeModules } from "../auth/wire";

const configuration = {
  issuer: "https://psc.example",
  authorization_endpoint: "https://psc.example/authorize",
  token_endpoint: "https://psc.example/token",
  jwks_uri: "https://psc.example/jwks",
} as OidcConfiguration;

function modules(overrides: Partial<NativeModules> = {}): NativeModules {
  const keychainCalls: Array<Record<string, unknown> | undefined> = [];

  return {
    keychain: {
      setGenericPassword: async (_u, _p, options) => {
        keychainCalls.push(options);
        return true;
      },
      getGenericPassword: async (options) => {
        keychainCalls.push(options);
        return false;
      },
      resetGenericPassword: async () => true,
    },
    authSession: { openAuthSessionAsync: async () => ({ type: "cancel" }) },
    crypto: {
      getRandomValues: (b) => b,
      sha256: async (d) => d,
    },
    clock: { now: () => 0 },
    verifier: { verify: async () => ({}) as never },
    exchange: { exchangeCode: async () => ({ tokens: {} as never }) },
    ...overrides,
    // Exposed for assertions without widening the public shape.
    ...({ keychainCalls } as unknown as Partial<NativeModules>),
  };
}

const options = {
  configuration,
  clientId: "shomer",
  redirectUri: "shomer://cb",
  scopes: ["openid"],
  service: "shomer-psc",
};

describe("wireShomer", () => {
  it("produces a client that starts idle", () => {
    const client = auth.wireShomer(options, modules());

    expect(client.state.status).toBe("idle");
  });

  it("refuses biometrics configured without a module", () => {
    // THE assertion. Silently skipping the wrapper would produce an app
    // whose lock is absent while its configuration says it is on — a
    // control missing with nothing reporting it, which is worse than one
    // that refuses to start.
    expect(() =>
      auth.wireShomer(
        { ...options, biometrics: { reason: "Unlock" } },
        modules({ biometrics: undefined }),
      ),
    ).toThrow(/no biometric module was supplied/);
  });

  it("wires the lock when both are supplied", () => {
    const client = auth.wireShomer(
      { ...options, biometrics: { reason: "Unlock" } },
      modules({
        biometrics: {
          isAvailable: async () => true,
          authenticate: async () => true,
        },
      }),
    );

    expect(client.state.status).toBe("idle");
  });
});

describe("the adapter entrypoint", () => {
  it.each([
    "ShomerClient",
    "AuthorizationError",
    "KeychainTokenStorage",
    "SystemBrowser",
    "isExpectedCallback",
    "parseCallback",
    "BiometricTokenStorage",
    "BiometricLockError",
    "ShomerProvider",
    "useAuth",
    "useSession",
    "useAccessToken",
    "wireShomer",
  ])("exports %s", (name) => {
    // Same reason lib has this test: every other file imports its subject
    // directly, so a module that is never exported passes all of them and
    // is unreachable for the screens meant to use it.
    expect(auth).toHaveProperty(name);
  });
});
