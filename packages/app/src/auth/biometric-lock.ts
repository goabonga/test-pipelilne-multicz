// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * The optional biometric lock.
 *
 * WHAT IT IS, AND THE MISTAKE THIS FILE EXISTS TO PREVENT
 *
 * It is a LOCAL UNLOCK. Face ID, a fingerprint or the device passcode
 * gates access to the Keychain entry on this device. That is the whole of
 * it.
 *
 * It is NOT a second authentication factor. The IdP never learns it
 * happened, no claim in any token reflects it, and `acr` still says
 * whatever the IdP asserted at sign-in. Presenting it to a user or an
 * auditor as multi-factor would be claiming an assurance level the flow
 * never obtained — and in a health context that claim is the kind that
 * gets written into a compliance document and believed.
 *
 * Where a real step-up is required, the mechanism is acr_values on a fresh
 * authorization: the IdP performs it, and the resulting token says so.
 * `requireStepUp` below is that, and it is deliberately a different
 * function from this one.
 */

import type { TokenStorage } from "@shomer/lib";

export interface BiometricModule {
  /** Whether the device has an enrolled biometric or a passcode set. */
  isAvailable(): Promise<boolean>;
  /**
   * Prompt. Resolves true when the user satisfied it, false when they
   * cancelled — cancelling is a decision, not an error.
   */
  authenticate(reason: string): Promise<boolean>;
}

export class BiometricLockError extends Error {
  constructor(
    message: string,
    readonly reason: "unavailable" | "refused",
  ) {
    super(message);
    this.name = "BiometricLockError";
  }
}

export interface BiometricLockOptions {
  /**
   * Shown in the system prompt. iOS requires it and Android displays it;
   * a vague one ("Authenticate") tells the user nothing about what they
   * are approving.
   */
  readonly reason: string;
  /**
   * What to do when the device has no biometric and no passcode.
   *
   * `deny` by default. Falling through to the tokens would mean the lock
   * is present on devices that happen to have a fingerprint and absent on
   * the ones where it matters most — which is a control that reports as
   * enabled and protects the wrong half of the fleet.
   */
  readonly whenUnavailable?: "deny" | "allow";
}

/**
 * Wraps a TokenStorage so reads require a local unlock.
 *
 * WRITES AND CLEARS DO NOT PROMPT, and that asymmetry is deliberate:
 *
 *   save   happens at the end of a sign-in the user just completed.
 *          Prompting again asks them to prove themselves twice for one
 *          action.
 *   clear  is sign-out. Requiring a fingerprint to sign out means a user
 *          whose enrolment changed cannot leave — trapped by their own
 *          credentials, which is the opposite of a security control.
 */
export class BiometricTokenStorage implements TokenStorage {
  readonly #inner: TokenStorage;
  readonly #biometrics: BiometricModule;
  readonly #options: BiometricLockOptions;

  constructor(inner: TokenStorage, biometrics: BiometricModule, options: BiometricLockOptions) {
    this.#inner = inner;
    this.#biometrics = biometrics;
    this.#options = options;
  }

  async load(): Promise<string | undefined> {
    if (!(await this.#biometrics.isAvailable())) {
      if ((this.#options.whenUnavailable ?? "deny") === "allow") {
        return this.#inner.load();
      }
      throw new BiometricLockError(
        "this device has no biometric or passcode configured",
        "unavailable",
      );
    }

    if (!(await this.#biometrics.authenticate(this.#options.reason))) {
      // Refusing is a decision. It is reported as its own reason so a
      // caller can offer the prompt again rather than signing the user
      // out, which is what an unrecognised failure would lead to.
      throw new BiometricLockError("the unlock was refused", "refused");
    }

    return this.#inner.load();
  }

  async save(value: string): Promise<void> {
    return this.#inner.save(value);
  }

  async clear(): Promise<void> {
    return this.#inner.clear();
  }
}
