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

// Upper bound to keep an honest-but-typo'd password from triggering
// quadratic work on the server-side (bcrypt/argon2 hashing scales
// with input length, and OWASP ASVS 2.1.4 caps the input at 128+);
// 256 leaves headroom for legitimate passphrases while killing
// pathological inputs at the form layer.
const MAX_PASSWORD_LENGTH = 256;

export function validateCredentials(creds: Credentials): string | null {
  if (!creds.username.trim()) return "username required";
  if (!creds.password) return "password required";
  if (creds.password.length < 8) return "password must be at least 8 characters";
  if (creds.password.length > MAX_PASSWORD_LENGTH) {
    return `password must be at most ${MAX_PASSWORD_LENGTH} characters`;
  }
  return null;
}
