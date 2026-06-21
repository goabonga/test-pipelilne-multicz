// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * Credential validation + error formatting.
 *
 * Framework-agnostic pure helpers shared by the React web bundle and
 * the React Native app, so the login form behaves identically on every
 * client. No DOM, no react, no react-native imports.
 */

export interface Credentials {
  username: string;
  password: string;
}

export function formatError(reason: string): string {
  if (!reason) return "";
  return `Sign-in failed: ${reason}`;
}

// Canonical form for a username: trimmed + lower-cased, so the web and
// mobile clients submit the same value regardless of stray spaces or
// capitalisation.
export function normalizeUsername(username: string): string {
  return username.trim().toLowerCase();
}

// Password length bounds, exported so the web and mobile login forms can
// surface matching hints/placeholders without re-declaring the numbers.
// The upper bound keeps an honest-but-typo'd password from triggering
// quadratic work server-side (bcrypt/argon2 hashing scales with input
// length, and OWASP ASVS 2.1.4 caps the input at 128+); 256 leaves
// headroom for legitimate passphrases while killing pathological inputs
// at the form layer.
export const PASSWORD_MIN_LENGTH = 8;
export const PASSWORD_MAX_LENGTH = 256;

export function validateCredentials(creds: Credentials): string | null {
  if (!creds.username.trim()) return "username required";
  if (!creds.password) return "password required";
  if (creds.password.length < PASSWORD_MIN_LENGTH) {
    return `password must be at least ${PASSWORD_MIN_LENGTH} characters`;
  }
  if (creds.password.length > PASSWORD_MAX_LENGTH) {
    return `password must be at most ${PASSWORD_MAX_LENGTH} characters`;
  }
  return null;
}
