// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

import {
  type AuthSessionModule,
  type AuthSessionResult,
  isExpectedCallback,
  parseCallback,
  SystemBrowser,
} from "../auth/system-browser";

function moduleReturning(result: AuthSessionResult): AuthSessionModule {
  return { openAuthSessionAsync: async () => result };
}

describe("SystemBrowser", () => {
  it("returns the callback url on success", async () => {
    const browser = new SystemBrowser(
      moduleReturning({ type: "success", url: "shomer://cb?code=abc" }),
    );

    expect(await browser.open("https://idp/auth", "shomer://cb")).toBe("shomer://cb?code=abc");
  });

  it("treats a cancel as no result rather than an error", async () => {
    // Cancelling a login is something users do deliberately. Rejecting
    // here produces an error dialog for a decision.
    const browser = new SystemBrowser(moduleReturning({ type: "cancel" }));

    await expect(browser.open("https://idp/auth", "shomer://cb")).resolves.toBeUndefined();
  });

  it("treats a dismiss the same way", async () => {
    const browser = new SystemBrowser(moduleReturning({ type: "dismiss" }));

    await expect(browser.open("https://idp/auth", "shomer://cb")).resolves.toBeUndefined();
  });

  it("treats an unknown result as not completed", async () => {
    // Written as a positive check on success rather than by listing the
    // cancel cases, so a library that adds a fourth result type reads as
    // "did not complete" instead of falling through as a success.
    const browser = new SystemBrowser({
      openAuthSessionAsync: async () => ({ type: "locked" }) as unknown as AuthSessionResult,
    });

    await expect(browser.open("https://idp/auth", "shomer://cb")).resolves.toBeUndefined();
  });
});

describe("isExpectedCallback", () => {
  it("accepts the redirect with the idp query appended", () => {
    expect(
      isExpectedCallback("https://app.example/cb?code=a&state=b", "https://app.example/cb"),
    ).toBe(true);
  });

  it("accepts the bare redirect", () => {
    expect(isExpectedCallback("https://app.example/cb", "https://app.example/cb")).toBe(true);
  });

  it("rejects a different redirect entirely", () => {
    expect(isExpectedCallback("https://evil.example/cb?code=a", "https://app.example/cb")).toBe(
      false,
    );
  });

  it("rejects a url that merely begins the same way", () => {
    // THE assertion here. A plain startsWith would accept this, and the
    // app cannot trust what arrives on its deep link: on Android an app
    // link can be delivered by anything able to construct an Intent.
    expect(
      isExpectedCallback("https://app.example/cb.evil.test/steal?code=a", "https://app.example/cb"),
    ).toBe(false);
  });

  it("rejects a longer path under the same prefix", () => {
    expect(isExpectedCallback("https://app.example/cbx?code=a", "https://app.example/cb")).toBe(
      false,
    );
  });

  it("accepts a fragment boundary", () => {
    expect(isExpectedCallback("https://app.example/cb#done", "https://app.example/cb")).toBe(true);
  });
});

describe("parseCallback", () => {
  it("pulls out code and state", () => {
    expect(parseCallback("shomer://cb?code=abc&state=xyz")).toEqual({
      code: "abc",
      state: "xyz",
      error: undefined,
      errorDescription: undefined,
    });
  });

  it("pulls out an error and its description", () => {
    // The IdP reports a refusal this way — a user declining consent, or an
    // acr_values the account cannot satisfy. Dropping it leaves the app
    // showing a generic failure for something the IdP explained.
    expect(
      parseCallback("shomer://cb?error=access_denied&error_description=user%20refused"),
    ).toMatchObject({ error: "access_denied", errorDescription: "user refused" });
  });

  it("decodes percent-encoded values", () => {
    expect(parseCallback("shomer://cb?state=a%2Fb%3Dc").state).toBe("a/b=c");
  });

  it("keeps the first of a duplicated parameter", () => {
    // An IdP sends each parameter once, so a second is somebody appending
    // to the URL. Taking the last would let them override the first — the
    // state the app is about to compare against.
    expect(parseCallback("shomer://cb?state=real&state=injected").state).toBe("real");
  });

  it("stops at the fragment", () => {
    // Otherwise `#anything` is folded into the last parameter's value, and
    // the state comparison fails for a reason nobody can see.
    expect(parseCallback("shomer://cb?state=abc#tracking").state).toBe("abc");
  });

  it("returns nothing for a url with no query", () => {
    expect(parseCallback("shomer://cb")).toEqual({
      code: undefined,
      state: undefined,
      error: undefined,
      errorDescription: undefined,
    });
  });

  it("survives a malformed query", () => {
    // A parser that throws here turns a hostile deep link into a crash,
    // which is a denial of service anything on the device can trigger.
    expect(() => parseCallback("shomer://cb?&=&code")).not.toThrow();
  });
});
