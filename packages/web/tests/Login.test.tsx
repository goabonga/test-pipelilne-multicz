import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, describe, expect, it, vi } from "vitest";
import { Login } from "../src/pages/Login";

const config = { appName: "Shomer", version: "test", loginAction: "/login" };

function renderLogin() {
  return render(
    <MemoryRouter initialEntries={["/login"]}>
      <Login config={config} />
    </MemoryRouter>,
  );
}

function fill(username: string, password: string): void {
  fireEvent.change(screen.getByLabelText("Username"), { target: { value: username } });
  fireEvent.change(screen.getByLabelText("Password"), { target: { value: password } });
}

describe("Login", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("blocks submit and renders the formatted error for invalid credentials", () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    const { container } = renderLogin();
    fill("alice", "short");
    const form = container.querySelector("form");
    if (!form) throw new Error("form missing");

    fireEvent.submit(form);

    expect(screen.getByText("Sign-in failed: password must be at least 8 characters")).toBeTruthy();
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("POSTs the credentials when they are valid", async () => {
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(new Response('{"status":"ok"}'));
    const { container } = renderLogin();
    fill("alice", "wonderland8");
    const form = container.querySelector("form");
    if (!form) throw new Error("form missing");

    fireEvent.submit(form);

    await waitFor(() =>
      expect(fetchSpy).toHaveBeenCalledWith("/login", expect.objectContaining({ method: "POST" })),
    );
  });
});
