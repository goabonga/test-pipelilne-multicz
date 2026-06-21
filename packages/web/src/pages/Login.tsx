// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * Login route of the SPA.
 *
 * Validates with @shomer/lib (the same logic the React Native app
 * runs), POSTs the credentials to the server, then navigates home
 * client-side. Auth is a stub today; the POST is wired so the flow is
 * exercised end-to-end.
 */

import { type Credentials, formatError, validateCredentials } from "@shomer/lib";
import { type FormEvent, useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import type { AppConfig } from "../config";

interface LoginProps {
  config: AppConfig;
}

export function Login({ config }: LoginProps) {
  const navigate = useNavigate();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    document.title = "Sign in — Shomer";
  }, []);

  async function handleSubmit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    const creds: Credentials = { username, password };
    const problem = validateCredentials(creds);
    if (problem !== null) {
      setError(formatError(problem));
      return;
    }
    setError("");
    try {
      await fetch(config.loginAction, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ username, password }),
      });
    } catch {
      // Stub auth — ignore transport errors in the demo and still
      // navigate so the SPA flow stays exercised end-to-end.
    }
    navigate("/");
  }

  return (
    <main>
      <h1>Sign in</h1>
      <form id="login" onSubmit={(event) => void handleSubmit(event)}>
        <label htmlFor="username">Username</label>
        <input
          id="username"
          name="username"
          type="text"
          autoComplete="username"
          required
          value={username}
          onChange={(event) => setUsername(event.target.value)}
        />

        <label htmlFor="password">Password</label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          value={password}
          onChange={(event) => setPassword(event.target.value)}
        />

        <p className="error">{error}</p>
        <button type="submit">Sign in</button>
      </form>
      <p>
        <Link to="/">Back</Link>
      </p>
    </main>
  );
}
