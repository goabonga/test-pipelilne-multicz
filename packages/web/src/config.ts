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

export function readConfig(): AppConfig {
  if (typeof document === "undefined") return DEFAULT_CONFIG;
  const el = document.getElementById("app-config");
  if (!el?.textContent) return DEFAULT_CONFIG;
  try {
    return { ...DEFAULT_CONFIG, ...JSON.parse(el.textContent) };
  } catch {
    return DEFAULT_CONFIG;
  }
}
