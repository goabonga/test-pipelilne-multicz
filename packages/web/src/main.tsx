// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * Web entrypoint.
 *
 * Mounts the React islands into the server-rendered Jinja pages. Each
 * island is opt-in: it renders only when its mount node exists, so a
 * page that doesn't carry `#login-root` ships no React work.
 */

import { createRoot } from "react-dom/client";
import { LoginForm } from "./components/LoginForm";
import { readConfig } from "./config";

const config = readConfig();

const loginRoot = document.getElementById("login-root");
if (loginRoot) {
  createRoot(loginRoot).render(<LoginForm config={config} />);
}
