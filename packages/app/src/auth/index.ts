// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * The React Native authentication adapter.
 *
 * NOTHING HERE IMPORTS A NATIVE MODULE. Every adapter takes the module it
 * needs as a constructor argument, so this file — and the tests — load
 * with no pods, no gradle and no mocks.
 *
 * The consequence is that wiring is the app's job and is written once, in
 * one place. `wireShomer` below is that place; it exists so the assembly
 * is reviewable rather than scattered across whichever screen happened to
 * need it first.
 */

export type { BiometricLockOptions, BiometricModule } from "./biometric-lock";
export { BiometricLockError, BiometricTokenStorage } from "./biometric-lock";
export type {
  ShomerClientDeps,
  ShomerClientOptions,
  TokenExchange,
} from "./client";
export { AuthorizationError, ShomerClient } from "./client";
export type { ShomerProviderProps } from "./context";
export {
  ShomerProvider,
  useAccessToken,
  useAuth,
  useSession,
} from "./context";
export type {
  KeychainModule,
  KeychainStorageOptions,
} from "./keychain-storage";
export { KeychainTokenStorage } from "./keychain-storage";
export type {
  AuthSessionModule,
  AuthSessionResult,
  CallbackParams,
} from "./system-browser";
export {
  isExpectedCallback,
  parseCallback,
  SystemBrowser,
} from "./system-browser";
export type { NativeModules, WireOptions } from "./wire";
export { wireShomer } from "./wire";
