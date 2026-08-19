// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

import type { OidcConfiguration, Tokens } from "@shomer/lib";

import { ShomerClient, type ShomerClientDeps } from "../auth/client";

const NOW = 1_760_000_000_000;
const REDIRECT = "shomer://callback";

const configuration = {
  issuer: "https://psc.example",
  authorization_endpoint: "https://psc.example/authorize",
  token_endpoint: "https://psc.example/token",
  jwks_uri: "https://psc.example/jwks",
} as OidcConfiguration;

const tokens: Tokens = {
  accessToken: "access",
  refreshToken: "refresh",
  expiresAt: NOW + 3_600_000,
};

/**
 * A browser that echoes back whatever the test asks for, and records the
 * authorization URL so the state can be read out of it — which is how a
 * real IdP would produce a matching callback.
 */
function harness(
  respond: (authorizeUrl: string) => string | undefined,
  overrides: Partial<ShomerClientDeps> = {},
) {
  const stored: string[] = [];
  let opened = "";
  let randomCall = 0;

  const deps: ShomerClientDeps = {
    browser: {
      async open(url) {
        opened = url;
        return respond(url);
      },
    },
    storage: {
      async load() {
        return stored.at(-1);
      },
      async save(value) {
        stored.push(value);
      },
      async clear() {
        stored.length = 0;
      },
    },
    crypto: {
      // Counts up across calls, so the verifier, the state and the nonce
      // are distinguishable. Filling with the index instead returns the
      // same bytes every time, which makes the three identical — and an
      // assertion that the verifier never reaches the URL then fails
      // because the state is in there and happens to equal it.
      getRandomValues(bytes) {
        randomCall += 1;
        for (let i = 0; i < bytes.length; i += 1) {
          bytes[i] = (randomCall * 31 + i) % 256;
        }
        return bytes;
      },
      async sha256(data) {
        return data.slice(0, 32);
      },
    },
    clock: { now: () => NOW },
    verifier: {
      verify: async () => ({
        iss: configuration.issuer,
        sub: "user-1",
        aud: "shomer",
        exp: NOW / 1000 + 300,
        iat: NOW / 1000 - 10,
        nonce: stateOf(opened, "nonce"),
      }),
    },
    exchange: {
      exchangeCode: async () => ({ tokens, idToken: "id-token" }),
    },
    ...overrides,
  };

  const client = new ShomerClient(
    {
      configuration,
      clientId: "shomer",
      redirectUri: REDIRECT,
      scopes: ["openid"],
    },
    deps,
  );

  return { client, stored, openedUrl: () => opened };
}

function stateOf(url: string, key: string): string {
  const match = new RegExp(`[?&]${key}=([^&]+)`).exec(url);
  return match ? decodeURIComponent(match[1] as string) : "";
}

describe("ShomerClient.signIn", () => {
  it("completes and stores the tokens", async () => {
    const h = harness((url) => `${REDIRECT}?code=abc&state=${stateOf(url, "state")}`);

    const claims = await h.client.signIn();

    expect(claims?.sub).toBe("user-1");
    expect(h.client.state.status).toBe("authenticated");
    expect(JSON.parse(h.stored[0] as string)).toEqual(tokens);
  });

  it("records the state before opening the browser", async () => {
    // On React Native the app can be evicted while the system browser is
    // in front. A state held only in a local would be gone when the
    // callback arrives, and the flow would fail its own check for a reason
    // indistinguishable from an attack.
    let statusWhileOpen = "";
    const h = harness((url) => {
      statusWhileOpen = h.client.state.status;
      return `${REDIRECT}?code=abc&state=${stateOf(url, "state")}`;
    });

    await h.client.signIn();

    expect(statusWhileOpen).toBe("authorizing");
  });

  it("rejects a callback whose state does not match", async () => {
    // THE assertion. Without it an attacker hands us a code obtained in
    // their own session and the victim ends up signed in as them.
    const h = harness(() => `${REDIRECT}?code=abc&state=not-the-one`);

    await expect(h.client.signIn()).rejects.toMatchObject({
      reason: "state_mismatch",
    });
    expect(h.stored).toHaveLength(0);
  });

  it("rejects a callback that is not our redirect", async () => {
    const h = harness((url) => `shomer://callback.evil/x?code=a&state=${stateOf(url, "state")}`);

    await expect(h.client.signIn()).rejects.toMatchObject({
      reason: "unexpected_callback",
    });
  });

  it("reports the idp refusal rather than a generic mismatch", async () => {
    // Consent declined, or an acr_values the account cannot satisfy. The
    // IdP explained itself; showing "state mismatch" instead throws that
    // away.
    const h = harness(() => `${REDIRECT}?error=access_denied&error_description=carte%20absente`);

    await expect(h.client.signIn()).rejects.toMatchObject({
      reason: "idp_error",
      message: "carte absente",
    });
  });

  it("treats a dismissal as cancelled, not as a failure", async () => {
    const h = harness(() => undefined);

    await expect(h.client.signIn()).rejects.toMatchObject({
      reason: "cancelled",
    });
  });

  it("rejects a callback with a matching state but no code", async () => {
    const h = harness((url) => `${REDIRECT}?state=${stateOf(url, "state")}`);

    await expect(h.client.signIn()).rejects.toMatchObject({ reason: "no_code" });
  });

  it("sends the verifier and never the challenge to the token endpoint", async () => {
    // The exchange proves possession with the verifier. Sending the
    // challenge would be sending the public half and the IdP would reject
    // it — but only at the last step, long after the useful error.
    let sent: { code: string; verifier: string } | undefined;
    const h = harness((url) => `${REDIRECT}?code=abc&state=${stateOf(url, "state")}`, {
      exchange: {
        async exchangeCode(input) {
          sent = input;
          return { tokens, idToken: "id-token" };
        },
      },
    });

    await h.client.signIn();

    expect(sent?.code).toBe("abc");
    expect(sent?.verifier).toBeTruthy();
    expect(h.openedUrl()).not.toContain(sent?.verifier as string);
  });

  it("stores nothing when the id token fails validation", async () => {
    // Storing first and validating after leaves a rejected token on the
    // device, which the next launch reads back and trusts.
    const h = harness((url) => `${REDIRECT}?code=abc&state=${stateOf(url, "state")}`, {
      verifier: {
        verify: async () => {
          throw new Error("bad signature");
        },
      },
    });

    await expect(h.client.signIn()).rejects.toThrow("bad signature");
    expect(h.stored).toHaveLength(0);
  });
});

describe("ShomerClient.restore", () => {
  it("adopts tokens written by a previous launch", async () => {
    const h = harness(() => undefined);
    h.stored.push(JSON.stringify(tokens));

    await expect(h.client.restore()).resolves.toEqual(tokens);
    expect(h.client.state.status).toBe("authenticated");
  });

  it("reports no session when storage is empty", async () => {
    const h = harness(() => undefined);

    await expect(h.client.restore()).resolves.toBeUndefined();
    expect(h.client.state.status).toBe("idle");
  });

  it("clears unreadable storage rather than crashing on launch", async () => {
    // Left in place, every future launch would fail the same way — an app
    // that cannot start until it is reinstalled.
    const h = harness(() => undefined);
    h.stored.push("not json");

    await expect(h.client.restore()).resolves.toBeUndefined();
    expect(h.stored).toHaveLength(0);
  });
});

describe("ShomerClient.signOut", () => {
  it("ends the session and clears storage", async () => {
    const h = harness((url) => `${REDIRECT}?code=abc&state=${stateOf(url, "state")}`);
    await h.client.signIn();

    await h.client.signOut();

    expect(h.client.state.status).toBe("idle");
    expect(h.stored).toHaveLength(0);
  });

  it("changes state before touching storage", async () => {
    // A storage failure must not leave the app believing it is still
    // signed in.
    const h = harness(() => undefined, {
      storage: {
        load: async () => undefined,
        save: async () => undefined,
        clear: async () => {
          throw new Error("keychain locked");
        },
      },
    });

    await expect(h.client.signOut()).rejects.toThrow("keychain locked");
    expect(h.client.state.status).toBe("idle");
  });
});
