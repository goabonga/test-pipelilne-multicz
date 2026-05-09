import { describe, expect, it } from "vitest";
import { formatError, setupLoginForm, validateCredentials } from "../src/main";

describe("formatError", () => {
  it("returns empty for empty reason", () => {
    expect(formatError("")).toBe("");
  });

  it("prefixes the reason with a stable label", () => {
    expect(formatError("invalid creds")).toBe("Sign-in failed: invalid creds");
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
});

describe("setupLoginForm", () => {
  it("blocks submit and renders the formatted error when credentials are invalid", () => {
    document.body.innerHTML = `
      <form id="login" method="post" action="/login">
        <input name="username" />
        <input name="password" />
        <p class="error"></p>
      </form>`;
    const form = document.querySelector<HTMLFormElement>("form#login");
    if (!form) throw new Error("test fixture missing");
    setupLoginForm(form);

    const usernameInput = form.querySelector<HTMLInputElement>("input[name=username]");
    const passwordInput = form.querySelector<HTMLInputElement>("input[name=password]");
    if (!usernameInput || !passwordInput) throw new Error("inputs missing");
    usernameInput.value = "alice";
    passwordInput.value = "short";

    const event = new Event("submit", { cancelable: true });
    form.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(true);
    expect(form.querySelector(".error")?.textContent).toBe(
      "Sign-in failed: password must be at least 8 characters",
    );
  });

  it("lets the submit through when credentials are valid", () => {
    document.body.innerHTML = `
      <form id="login" method="post" action="/login">
        <input name="username" />
        <input name="password" />
        <p class="error"></p>
      </form>`;
    const form = document.querySelector<HTMLFormElement>("form#login");
    if (!form) throw new Error("test fixture missing");
    setupLoginForm(form);

    const usernameInput = form.querySelector<HTMLInputElement>("input[name=username]");
    const passwordInput = form.querySelector<HTMLInputElement>("input[name=password]");
    if (!usernameInput || !passwordInput) throw new Error("inputs missing");
    usernameInput.value = "alice";
    passwordInput.value = "wonderland8";

    const event = new Event("submit", { cancelable: true });
    form.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(false);
  });
});
