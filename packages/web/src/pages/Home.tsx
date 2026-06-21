// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * Home route of the SPA.
 */

import { useEffect } from "react";
import { Link } from "react-router-dom";

export function Home() {
  useEffect(() => {
    document.title = "Shomer";
  }, []);

  return (
    <main>
      <h1>Shomer</h1>
      <p>OAuth2 / OpenID Connect authorization server.</p>
      <p>
        <Link to="/login">Sign in</Link>
      </p>
    </main>
  );
}
