import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it } from "vitest";
import { AppRoutes } from "../src/App";

const config = { appName: "Shomer", version: "test", loginAction: "/login" };

function renderAt(path: string) {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <AppRoutes config={config} />
    </MemoryRouter>,
  );
}

describe("AppRoutes", () => {
  it("renders the Home page at /", () => {
    renderAt("/");
    expect(screen.getByRole("heading", { name: "Shomer" })).toBeTruthy();
    expect(screen.getByRole("link", { name: "Sign in" })).toBeTruthy();
  });

  it("renders the Login page at /login", () => {
    renderAt("/login");
    expect(screen.getByRole("heading", { name: "Sign in" })).toBeTruthy();
    expect(screen.getByLabelText("Username")).toBeTruthy();
    expect(screen.getByLabelText("Password")).toBeTruthy();
  });

  it("falls back to Home for unknown routes", () => {
    renderAt("/does-not-exist");
    expect(screen.getByRole("heading", { name: "Shomer" })).toBeTruthy();
  });
});
