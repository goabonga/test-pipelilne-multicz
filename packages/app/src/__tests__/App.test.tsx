/**
 * @format
 */

import { validateCredentials } from "@shomer/lib";

// Proves the app resolves @shomer/lib (Metro alias / jest moduleNameMapper)
// and shares the exact validation the web client uses.
describe("shared validation via @shomer/lib", () => {
  it("rejects a short password with the shared message", () => {
    expect(validateCredentials({ username: "alice", password: "short" })).toBe(
      "password must be at least 8 characters",
    );
  });

  it("accepts a valid pair", () => {
    expect(validateCredentials({ username: "alice", password: "wonderland8" })).toBeNull();
  });
});
