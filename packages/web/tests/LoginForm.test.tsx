import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { LoginForm } from "../src/components/LoginForm";

const config = { appName: "Shomer", version: "test", loginAction: "/login" };

function fill(username: string, password: string): void {
  fireEvent.change(screen.getByLabelText("Username"), { target: { value: username } });
  fireEvent.change(screen.getByLabelText("Password"), { target: { value: password } });
}

describe("LoginForm", () => {
  it("blocks submit and renders the formatted error for invalid credentials", () => {
    const { container } = render(<LoginForm config={config} />);
    fill("alice", "short");
    const form = container.querySelector("form");
    if (!form) throw new Error("form missing");

    // fireEvent.submit returns false when preventDefault was called.
    const notPrevented = fireEvent.submit(form);

    expect(notPrevented).toBe(false);
    expect(screen.getByText("Sign-in failed: password must be at least 8 characters")).toBeTruthy();
  });

  it("lets the submit through (would POST) when credentials are valid", () => {
    const { container } = render(<LoginForm config={config} />);
    fill("alice", "wonderland8");
    const form = container.querySelector("form");
    if (!form) throw new Error("form missing");

    const notPrevented = fireEvent.submit(form);

    expect(notPrevented).toBe(true);
  });
});
