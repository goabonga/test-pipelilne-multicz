// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * The system browser, per RFC 8252.
 *
 * ASWebAuthenticationSession on iOS, Custom Tabs on Android. Both share
 * the browser's cookie jar — which is what makes single sign-on work — and
 * both hand control back to the app on redirect without the app ever
 * seeing the page.
 *
 * NOT A WebView, and the distinction is the whole point rather than a
 * preference. An embedded WebView lets this app read every keystroke and
 * the DOM, so a user has no way to tell a real IdP page from one being
 * watched. Pro Santé Connect refuses them outright.
 *
 * WHY THE MODULE IS INJECTED
 *
 * The candidates are not equivalent and the choice is live:
 * expo-web-browser was published two days ago and requires expo-modules-
 * core in a bare app; react-native-inappbrowser-reborn was published five
 * months ago and installs as a plain native module. Both expose the same
 * shape — open a URL, resolve with a result — so the adapter takes that
 * shape and the decision stays at the wiring point, where it is one
 * function to change rather than a rewrite.
 */

import type { Browser } from "@shomer/lib";

/**
 * What both candidate libraries return. The discriminant matters: a
 * dismissal is not a failure, and collapsing the two is what turns a
 * user's decision into an error dialog.
 */
export type AuthSessionResult =
  | { readonly type: "success"; readonly url: string }
  | { readonly type: "cancel" }
  | { readonly type: "dismiss" };

/** The subset of expo-web-browser / inappbrowser this adapter uses. */
export interface AuthSessionModule {
  openAuthSessionAsync(url: string, redirectUri: string): Promise<AuthSessionResult>;
}

export class SystemBrowser implements Browser {
  readonly #module: AuthSessionModule;

  constructor(module: AuthSessionModule) {
    this.#module = module;
  }

  async open(url: string, redirectUri: string): Promise<string | undefined> {
    const result = await this.#module.openAuthSessionAsync(url, redirectUri);

    // Anything that is not an explicit success is a dismissal. Written as
    // a positive check rather than by listing the cancel cases: a library
    // that adds a fourth result type should read as "did not complete"
    // here, not fall through as though it had succeeded.
    return result.type === "success" ? result.url : undefined;
  }
}

/**
 * Whether a callback URL is one this client asked for.
 *
 * THE APP CANNOT TRUST WHAT ARRIVES ON ITS DEEP LINK. On Android an app
 * link can be delivered by anything that can construct an Intent, and on
 * both platforms a URL can be crafted by hand. So a callback is a claim
 * until it matches the redirect this flow started with.
 *
 * Compared as a prefix, because the IdP appends its own query — but a
 * prefix comparison on a raw string would accept
 * `https://app.example/callback.evil.test/...` for a redirect of
 * `https://app.example/callback`, so the boundary character is checked
 * too.
 */
export function isExpectedCallback(callbackUrl: string, redirectUri: string): boolean {
  if (!callbackUrl.startsWith(redirectUri)) {
    return false;
  }

  const rest = callbackUrl.slice(redirectUri.length);
  // Exactly the redirect, or the redirect followed by a query or a
  // fragment. Anything else is a longer path that merely begins the same
  // way.
  return rest === "" || rest.startsWith("?") || rest.startsWith("#");
}

/**
 * Pull the authorization response out of a callback URL.
 *
 * Parsed by hand for the same reason the authorization request is built by
 * hand: React Native's URL polyfill has had unreliable searchParams
 * support, and a parser that works in a browser and silently returns
 * undefined on a device is the worst shape this bug can take.
 */
export interface CallbackParams {
  readonly code?: string;
  readonly state?: string;
  readonly error?: string;
  readonly errorDescription?: string;
}

export function parseCallback(callbackUrl: string): CallbackParams {
  const queryStart = callbackUrl.indexOf("?");
  if (queryStart === -1) {
    return {};
  }

  // Stop at the fragment: an authorization code never lives there for a
  // code flow, and including it would fold `#anything` into the last
  // parameter's value.
  const fragmentStart = callbackUrl.indexOf("#", queryStart);
  const query = callbackUrl.slice(queryStart + 1, fragmentStart === -1 ? undefined : fragmentStart);

  const found: Record<string, string> = {};
  for (const pair of query.split("&")) {
    if (pair === "") {
      continue;
    }
    const equals = pair.indexOf("=");
    const key = decodeURIComponent(equals === -1 ? pair : pair.slice(0, equals));
    const value = equals === -1 ? "" : decodeURIComponent(pair.slice(equals + 1));
    // First wins. A duplicated parameter is not something to merge or
    // overwrite: an IdP sends each once, so a second is somebody appending
    // to the URL, and taking the last would let them override the first.
    if (!(key in found)) {
      found[key] = value;
    }
  }

  return {
    code: found.code,
    state: found.state,
    error: found.error,
    errorDescription: found.error_description,
  };
}
