# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""The BFF half of the authentication design.

The SPA holds no tokens. It talks to these routes, which hold the session
server-side and hand the browser nothing but an opaque cookie — so a
cross-site script that reads every variable in the page still finds no
access token, because there is not one to find.

That is the whole reason this exists rather than the browser talking to
the IdP directly.
"""
