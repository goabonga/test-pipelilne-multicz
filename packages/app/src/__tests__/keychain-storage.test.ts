// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

import { type KeychainModule, KeychainTokenStorage } from "../auth/keychain-storage";

/**
 * A stand-in for react-native-keychain, shaped exactly as it behaves —
 * including returning `false` rather than null for an empty slot, which is
 * the detail an adapter gets wrong.
 */
function fakeKeychain() {
  let stored: { username: string; password: string } | false = false;
  const calls: Array<{ method: string; options?: Record<string, unknown> }> = [];

  const keychain: KeychainModule = {
    async setGenericPassword(username, password, options) {
      calls.push({ method: "set", options });
      stored = { username, password };
      return true;
    },
    async getGenericPassword(options) {
      calls.push({ method: "get", options });
      return stored;
    },
    async resetGenericPassword(options) {
      calls.push({ method: "reset", options });
      stored = false;
      return true;
    },
  };

  return { keychain, calls, peek: () => stored };
}

describe("KeychainTokenStorage", () => {
  it("round-trips a value", async () => {
    const { keychain } = fakeKeychain();
    const storage = new KeychainTokenStorage(keychain, { service: "shomer" });

    await storage.save("the-tokens");

    expect(await storage.load()).toBe("the-tokens");
  });

  it("reports an empty slot as undefined rather than failing", async () => {
    // react-native-keychain returns `false` for "nothing stored". An
    // adapter that passes that through, or treats it as an error, makes a
    // first launch look like a failure.
    const { keychain } = fakeKeychain();
    const storage = new KeychainTokenStorage(keychain, { service: "shomer" });

    expect(await storage.load()).toBeUndefined();
  });

  it("stores with the strictest accessibility by default", async () => {
    // THE assertion in this file, and it is two guarantees rather than
    // one. WhenUnlocked keeps the item unreadable while the device is
    // locked; ThisDeviceOnly keeps it out of iCloud Keychain and encrypted
    // backups, so a stolen backup is not a stolen session.
    //
    // The commonly used AfterFirstUnlock drops the first half — readable
    // while locked — which is convenient for background work and wrong for
    // credentials.
    const { keychain, calls } = fakeKeychain();
    const storage = new KeychainTokenStorage(keychain, { service: "shomer" });

    await storage.save("t");

    expect(calls[0]?.options?.accessible).toBe("AccessibleWhenUnlockedThisDeviceOnly");
  });

  it("never falls back to the platform default", async () => {
    // Omitting `accessible` gives whatever the OS picks, which is more
    // permissive than this. Defaulted in the adapter so a caller cannot
    // reach that state by leaving an option out.
    const { keychain, calls } = fakeKeychain();
    const storage = new KeychainTokenStorage(keychain, { service: "shomer" });

    await storage.save("t");
    await storage.load();

    for (const call of calls) {
      expect(call.options?.accessible).toBeDefined();
    }
  });

  it("asks for a local unlock only when told to", async () => {
    const { keychain, calls } = fakeKeychain();
    const storage = new KeychainTokenStorage(keychain, {
      service: "shomer",
      requireBiometrics: true,
    });

    await storage.save("t");

    expect(calls[0]?.options?.accessControl).toBe("BiometryCurrentSet");
  });

  it("does not ask for biometrics by default", async () => {
    const { keychain, calls } = fakeKeychain();
    const storage = new KeychainTokenStorage(keychain, { service: "shomer" });

    await storage.save("t");

    expect(calls[0]?.options?.accessControl).toBeUndefined();
  });

  it("scopes every operation to the configured service", async () => {
    // Without it the entry collides with any other app using the default
    // service on the same device.
    const { keychain, calls } = fakeKeychain();
    const storage = new KeychainTokenStorage(keychain, { service: "shomer-psc" });

    await storage.save("t");
    await storage.load();
    await storage.clear();

    for (const call of calls) {
      expect(call.options?.service).toBe("shomer-psc");
    }
  });

  it("clears without reading first", async () => {
    // Sign-out has to work when the entry is unreadable. A changed
    // biometric enrolment invalidates a BiometryCurrentSet item, and a
    // user in that state must still be able to sign out rather than being
    // trapped by their own credentials.
    const { keychain, calls } = fakeKeychain();
    const storage = new KeychainTokenStorage(keychain, {
      service: "shomer",
      requireBiometrics: true,
    });

    await storage.clear();

    expect(calls.map((c) => c.method)).toEqual(["reset"]);
    expect(calls[0]?.options?.accessControl).toBeUndefined();
  });

  it("is idempotent when there is nothing to clear", async () => {
    const { keychain } = fakeKeychain();
    const storage = new KeychainTokenStorage(keychain, { service: "shomer" });

    await expect(storage.clear()).resolves.toBeUndefined();
    await expect(storage.clear()).resolves.toBeUndefined();
  });
});
