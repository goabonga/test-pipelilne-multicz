// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * Runtime config handed from the server to the React islands.
 *
 * shomer-ssr renders `{{ config | tojson }}` into a
 * `<script id="app-config" type="application/json">` tag (see
 * templates/base.html); the islands read it at mount time. Keeping the
 * server as the single source of truth means no config is duplicated in
 * the bundle.
 */

export interface AppConfig {
  appName: string;
  version: string;
  loginAction: string;
}

const DEFAULT_CONFIG: AppConfig = {
  appName: "Shomer",
  version: "dev",
  loginAction: "/login",
};

/**
 * Keep only the keys AppConfig declares, and only when they are strings.
 *
 * The previous version spread the parsed JSON straight over the defaults,
 * which trusted the payload's shape. A parsed array or string spreads to
 * numeric or index keys, and `{"version": null}` overwrote the default
 * with null — rendering the literal "null" in the UI rather than falling
 * back. Both parse fine, so the try/catch never saw them.
 */
function coerce(parsed: unknown): Partial<AppConfig> {
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    return {};
  }
  const source = parsed as Record<string, unknown>;
  const out: Partial<AppConfig> = {};
  for (const key of Object.keys(DEFAULT_CONFIG) as (keyof AppConfig)[]) {
    const value = source[key];
    if (typeof value === "string") out[key] = value;
  }
  return out;
}

export function readConfig(): AppConfig {
  if (typeof document === "undefined") return DEFAULT_CONFIG;
  const el = document.getElementById("app-config");
  if (!el?.textContent) return DEFAULT_CONFIG;
  try {
    return { ...DEFAULT_CONFIG, ...coerce(JSON.parse(el.textContent)) };
  } catch {
    return DEFAULT_CONFIG;
  }
}
