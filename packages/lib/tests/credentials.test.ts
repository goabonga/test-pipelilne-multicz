import { describe, expect, it } from "vitest";
import {
  formatError,
  normalizeUsername,
  sanitizeCredentials,
  validateCredentials,
} from "../src/index";

describe("formatError", () => {
  it("returns empty for empty reason", () => {
    expect(formatError("")).toBe("");
  });

  it("prefixes the reason with a stable label", () => {
    expect(formatError("invalid creds")).toBe("Sign-in failed: invalid creds");
  });
});

describe("normalizeUsername", () => {
  it("trims surrounding whitespace and lower-cases", () => {
    expect(normalizeUsername("  Alice  ")).toBe("alice");
  });

  it("leaves an already-canonical value untouched", () => {
    expect(normalizeUsername("bob")).toBe("bob");
  });
});

describe("sanitizeCredentials", () => {
  it("normalises the username but leaves the password intact", () => {
    expect(sanitizeCredentials({ username: "  Alice ", password: "  Secret " })).toEqual({
      username: "alice",
      password: "  Secret ",
    });
  });
});

describe("validateCredentials", () => {
  it("returns null for a valid pair", () => {
    expect(validateCredentials({ username: "alice", password: "wonderland8" })).toBeNull();
  });

  it("rejects an empty username", () => {
    expect(validateCredentials({ username: "  ", password: "wonderland8" })).toBe(
      "username required",
    );
  });

  it("rejects an empty password", () => {
    expect(validateCredentials({ username: "alice", password: "" })).toBe("password required");
  });

  it("rejects a short password", () => {
    expect(validateCredentials({ username: "alice", password: "short" })).toBe(
      "password must be at least 8 characters",
    );
  });

  it("rejects an over-long password", () => {
    expect(validateCredentials({ username: "alice", password: "x".repeat(257) })).toBe(
      "password must be at most 256 characters",
    );
  });
});
