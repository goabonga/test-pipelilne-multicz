// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * Login island.
 *
 * React-rendered replacement for the previous server-form + vanilla-JS
 * validation. The same pure helpers from @shomer/lib that the React
 * Native app uses drive validation here, so the two clients stay in
 * lock-step. A valid submit posts natively to `config.loginAction`; an
 * invalid one is blocked client-side and the formatted error rendered.
 */

import { type Credentials, formatError, validateCredentials } from "@shomer/lib";
import { type FormEvent, useState } from "react";
import type { AppConfig } from "../config";

interface LoginFormProps {
  config: AppConfig;
}

export function LoginForm({ config }: LoginFormProps) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  function handleSubmit(event: FormEvent<HTMLFormElement>): void {
    const creds: Credentials = { username, password };
    const problem = validateCredentials(creds);
    if (problem !== null) {
      event.preventDefault();
      setError(formatError(problem));
    }
  }

  return (
    <form id="login" method="post" action={config.loginAction} onSubmit={handleSubmit}>
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
  );
}
