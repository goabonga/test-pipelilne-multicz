// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

import { beforeEach, describe, expect, it } from "vitest";
import { readConfig } from "../src/config";

function inject(json: string): void {
  document.body.innerHTML = `<script id="app-config" type="application/json">${json}</script>`;
}

describe("readConfig", () => {
  beforeEach(() => {
    document.body.innerHTML = "";
  });

  it("falls back to defaults when no config tag is present", () => {
    expect(readConfig().appName).toBe("Shomer");
  });

  it("reads the values the server injected", () => {
    inject(JSON.stringify({ appName: "Tenant", version: "1.2.3" }));
    const cfg = readConfig();
    expect(cfg.appName).toBe("Tenant");
    expect(cfg.version).toBe("1.2.3");
    expect(cfg.loginAction).toBe("/login");
  });

  // The three payloads below all parse, so the try/catch never saw them.
  it("ignores a null value rather than rendering it", () => {
    inject('{"version": null}');
    expect(readConfig().version).toBe("dev");
  });

  it("ignores a non-string value", () => {
    inject('{"version": 3}');
    expect(readConfig().version).toBe("dev");
  });

  it("ignores a payload that is not an object", () => {
    inject('["nope"]');
    expect(readConfig()).toEqual({ appName: "Shomer", version: "dev", loginAction: "/login" });
  });

  it("drops keys AppConfig does not declare", () => {
    inject('{"appName": "Tenant", "injected": "surprise"}');
    expect(readConfig()).not.toHaveProperty("injected");
  });

  it("falls back when the payload is not valid JSON", () => {
    inject("{not json");
    expect(readConfig().appName).toBe("Shomer");
  });
});
