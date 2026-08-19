// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

import type { TokenStorage } from "@shomer/lib";

import { type BiometricModule, BiometricTokenStorage } from "../auth/biometric-lock";

function inMemoryStorage(initial?: string) {
  let value = initial;
  const calls: string[] = [];

  const storage: TokenStorage = {
    async load() {
      calls.push("load");
      return value;
    },
    async save(v) {
      calls.push("save");
      value = v;
    },
    async clear() {
      calls.push("clear");
      value = undefined;
    },
  };

  return { storage, calls, peek: () => value };
}

function biometrics(available: boolean, approves: boolean) {
  const prompts: string[] = [];
  const module: BiometricModule = {
    isAvailable: async () => available,
    authenticate: async (reason) => {
      prompts.push(reason);
      return approves;
    },
  };
  return { module, prompts };
}

const reason = "Unlock Shomer to access your session";

describe("BiometricTokenStorage", () => {
  it("returns the value once the unlock succeeds", async () => {
    const inner = inMemoryStorage("tokens");
    const bio = biometrics(true, true);
    const storage = new BiometricTokenStorage(inner.storage, bio.module, {
      reason,
    });

    expect(await storage.load()).toBe("tokens");
    expect(bio.prompts).toEqual([reason]);
  });

  it("does not read storage when the unlock is refused", async () => {
    // Reading first and discarding would put the tokens in memory for a
    // user who just declined to prove they are holding the device.
    const inner = inMemoryStorage("tokens");
    const storage = new BiometricTokenStorage(inner.storage, biometrics(true, false).module, {
      reason,
    });

    await expect(storage.load()).rejects.toMatchObject({ reason: "refused" });
    expect(inner.calls).toEqual([]);
  });

  it("denies by default when the device has no biometric", async () => {
    // THE assertion. Falling through to the tokens would leave the lock
    // present on devices that happen to have a fingerprint and absent on
    // the ones where it matters most — a control that reports as enabled
    // and protects the wrong half of the fleet.
    const inner = inMemoryStorage("tokens");
    const storage = new BiometricTokenStorage(inner.storage, biometrics(false, true).module, {
      reason,
    });

    await expect(storage.load()).rejects.toMatchObject({
      reason: "unavailable",
    });
    expect(inner.calls).toEqual([]);
  });

  it("can be told to allow when unavailable, explicitly", async () => {
    const inner = inMemoryStorage("tokens");
    const storage = new BiometricTokenStorage(inner.storage, biometrics(false, true).module, {
      reason,
      whenUnavailable: "allow",
    });

    expect(await storage.load()).toBe("tokens");
  });

  it("distinguishes a refusal from an unavailable device", async () => {
    // A refusal deserves another prompt; an unavailable device does not,
    // and offering one would loop. Collapsing both into one error leads a
    // caller to sign the user out for declining once.
    const refused = new BiometricTokenStorage(
      inMemoryStorage("t").storage,
      biometrics(true, false).module,
      { reason },
    );
    const unavailable = new BiometricTokenStorage(
      inMemoryStorage("t").storage,
      biometrics(false, false).module,
      { reason },
    );

    await expect(refused.load()).rejects.toMatchObject({ reason: "refused" });
    await expect(unavailable.load()).rejects.toMatchObject({
      reason: "unavailable",
    });
  });

  it("does not prompt on save", async () => {
    // save happens at the end of a sign-in the user just completed.
    // Prompting again asks them to prove themselves twice for one action.
    const inner = inMemoryStorage();
    const bio = biometrics(true, true);
    const storage = new BiometricTokenStorage(inner.storage, bio.module, {
      reason,
    });

    await storage.save("fresh");

    expect(bio.prompts).toEqual([]);
    expect(inner.peek()).toBe("fresh");
  });

  it("does not prompt on clear", async () => {
    // Requiring a fingerprint to sign out means a user whose enrolment
    // changed cannot leave — trapped by their own credentials, which is
    // the opposite of a security control.
    const inner = inMemoryStorage("tokens");
    const bio = biometrics(true, false);
    const storage = new BiometricTokenStorage(inner.storage, bio.module, {
      reason,
    });

    await storage.clear();

    expect(bio.prompts).toEqual([]);
    expect(inner.peek()).toBeUndefined();
  });

  it("shows the caller-supplied reason", async () => {
    // iOS requires one and Android displays it. A vague prompt tells the
    // user nothing about what they are approving.
    const bio = biometrics(true, true);
    const storage = new BiometricTokenStorage(inMemoryStorage("t").storage, bio.module, {
      reason: "Confirm it is you before opening a patient record",
    });

    await storage.load();

    expect(bio.prompts[0]).toBe("Confirm it is you before opening a patient record");
  });
});
