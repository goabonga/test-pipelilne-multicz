// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * Where the native modules meet the adapters.
 *
 * THE ONLY FILE THAT SHOULD EVER IMPORT ONE. Everything else takes what it
 * needs as an argument, which is what keeps the tests free of mocks and
 * the library choice reversible — see the note in ./index.
 *
 * It is deliberately not doing the importing yet. Picking between
 * expo-web-browser and react-native-inappbrowser-reborn is a real decision
 * with an install cost on both platforms, and making it here would bury it
 * in a function nobody reviews. The caller passes the modules in; this
 * assembles them in the right order, which is the part worth writing down.
 */

import type { Clock, Crypto, JwtVerifier, OidcConfiguration } from "@shomer/lib";

import {
  type BiometricLockOptions,
  type BiometricModule,
  BiometricTokenStorage,
} from "./biometric-lock";
import { ShomerClient, type TokenExchange } from "./client";
import { type KeychainModule, KeychainTokenStorage } from "./keychain-storage";
import { type AuthSessionModule, SystemBrowser } from "./system-browser";

export interface WireOptions {
  readonly configuration: OidcConfiguration;
  readonly clientId: string;
  readonly redirectUri: string;
  readonly scopes: readonly string[];
  /**
   * Pro Santé Connect uses this to demand an assurance level. Absent, the
   * IdP satisfies the request with whatever session it already has.
   */
  readonly acrValues?: readonly string[];
  /** Keychain service name. Changing it orphans the previous entry. */
  readonly service: string;
  /** Omit for no local unlock. */
  readonly biometrics?: BiometricLockOptions;
}

export interface NativeModules {
  readonly keychain: KeychainModule;
  readonly authSession: AuthSessionModule;
  readonly biometrics?: BiometricModule;
  readonly crypto: Crypto;
  readonly clock: Clock;
  readonly verifier: JwtVerifier;
  readonly exchange: TokenExchange;
}

export function wireShomer(options: WireOptions, modules: NativeModules): ShomerClient {
  const keychain = new KeychainTokenStorage(modules.keychain, {
    service: options.service,
    // Passed through so the Keychain item itself carries the biometric
    // access control, not only the wrapper below. Both matter: the wrapper
    // prompts, the access control is what the OS enforces if anything
    // reads the item another way.
    requireBiometrics: options.biometrics !== undefined,
  });

  // Asking for a lock without supplying the module is a configuration
  // mistake that would otherwise produce an app with no lock and no
  // warning — the control silently absent, which is worse than refused.
  if (options.biometrics && !modules.biometrics) {
    throw new Error("biometrics were configured but no biometric module was supplied");
  }

  const storage =
    options.biometrics && modules.biometrics
      ? new BiometricTokenStorage(keychain, modules.biometrics, options.biometrics)
      : keychain;

  return new ShomerClient(
    {
      configuration: options.configuration,
      clientId: options.clientId,
      redirectUri: options.redirectUri,
      scopes: options.scopes,
      acrValues: options.acrValues,
    },
    {
      browser: new SystemBrowser(modules.authSession),
      storage,
      crypto: modules.crypto,
      clock: modules.clock,
      verifier: modules.verifier,
      exchange: modules.exchange,
    },
  );
}
