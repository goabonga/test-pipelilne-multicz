// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * Token storage backed by the iOS Keychain and the Android Keystore.
 *
 * WHY THE NATIVE MODULE IS INJECTED RATHER THAN IMPORTED
 *
 * react-native-keychain is a native module: importing it here would mean
 * this file cannot be loaded by jest without a mock, cannot be typechecked
 * without the package installed, and cannot be reviewed without deciding
 * which library the app uses. That decision is real and reversible — the
 * ecosystem around React Native auth libraries moves — so it belongs at
 * the wiring point rather than baked into the adapter.
 *
 * The shape below is react-native-keychain's, so wiring it is one adapter
 * function, and swapping it is one adapter function.
 *
 * WHAT `accessible` ACTUALLY CONTROLS
 *
 * WHEN_UNLOCKED_THIS_DEVICE_ONLY is two separate guarantees and both
 * matter for a health context:
 *
 *   WHEN_UNLOCKED     the item is unreadable while the device is locked,
 *                     so a phone taken from a desk is not a phone whose
 *                     tokens can be extracted
 *   THIS_DEVICE_ONLY  the item is excluded from iCloud Keychain and from
 *                     encrypted backups, so it cannot be restored onto
 *                     another device — which is what turns a stolen
 *                     backup into a stolen session
 *
 * The commonly used AFTER_FIRST_UNLOCK drops the first guarantee: it stays
 * readable while the device is locked, which is convenient for background
 * work and wrong for credentials.
 */

import type { TokenStorage } from "@shomer/lib";

/** The subset of react-native-keychain this adapter uses. */
export interface KeychainModule {
  setGenericPassword(
    username: string,
    password: string,
    options?: Record<string, unknown>,
  ): Promise<unknown>;
  getGenericPassword(
    options?: Record<string, unknown>,
  ): Promise<false | { username: string; password: string }>;
  resetGenericPassword(options?: Record<string, unknown>): Promise<boolean>;
}

export interface KeychainStorageOptions {
  /**
   * Distinguishes this app's entry from every other one on the device.
   * Changing it orphans whatever was stored under the old value rather
   * than migrating it.
   */
  readonly service: string;
  /**
   * Passed straight through to the native module. Defaulted rather than
   * required so a caller cannot end up with the platform default by
   * omission, which is more permissive than this.
   */
  readonly accessible?: string;
  /** Prompt an unlock — Face ID, fingerprint, passcode — before reading. */
  readonly requireBiometrics?: boolean;
}

const DEFAULT_ACCESSIBLE = "AccessibleWhenUnlockedThisDeviceOnly";

/**
 * The Keychain stores a username/password pair; there is only one secret
 * here, so the username is a constant. It has to be stable: changing it
 * makes the previous entry unreadable without deleting it, which leaves a
 * secret on the device that nothing will ever clear.
 */
const ACCOUNT = "shomer.tokens";

export class KeychainTokenStorage implements TokenStorage {
  readonly #keychain: KeychainModule;
  readonly #options: KeychainStorageOptions;

  constructor(keychain: KeychainModule, options: KeychainStorageOptions) {
    this.#keychain = keychain;
    this.#options = options;
  }

  #nativeOptions(): Record<string, unknown> {
    const options: Record<string, unknown> = {
      service: this.#options.service,
      accessible: this.#options.accessible ?? DEFAULT_ACCESSIBLE,
    };

    if (this.#options.requireBiometrics) {
      // A LOCAL UNLOCK, AND NOTHING MORE. This proves the person holding
      // the device can unlock it; it is not a second authentication factor
      // and does not involve the IdP. Presenting it as one would be
      // claiming an assurance level the flow never obtained.
      options.accessControl = "BiometryCurrentSet";
    }

    return options;
  }

  async load(): Promise<string | undefined> {
    // `false` is what this module returns for "nothing stored", which is
    // not an error and must not be surfaced as one — a first launch would
    // otherwise look like a failure.
    const entry = await this.#keychain.getGenericPassword(this.#nativeOptions());
    return entry === false ? undefined : entry.password;
  }

  async save(value: string): Promise<void> {
    await this.#keychain.setGenericPassword(ACCOUNT, value, this.#nativeOptions());
  }

  async clear(): Promise<void> {
    // Deliberately not reading first. Sign-out has to work when the entry
    // is unreadable — a changed biometric enrolment invalidates a
    // BiometryCurrentSet item, and a user in that state must still be able
    // to sign out rather than being trapped by their own credentials.
    await this.#keychain.resetGenericPassword({
      service: this.#options.service,
    });
  }
}
