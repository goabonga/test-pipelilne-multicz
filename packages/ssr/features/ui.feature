# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

Feature: Browser-driven UI flows
  As a Shomer end user
  I want the public pages to render and the login form to redirect
  on submit so the SSR pipeline (web build → Jinja templates →
  uvicorn) actually behaves end-to-end.

  Scenarios run under Playwright (headless Chromium) so the rendered
  DOM and form-submit redirects are exercised through a real browser,
  not just an HTTP shape check.

  Scenario: home page renders the Shomer branding
    When the user navigates to "/"
    Then the page title contains "Shomer"
    And the rendered HTML includes "shomer-ssr"

  Scenario: login form renders the credential inputs
    When the user navigates to "/login"
    Then the page title contains "Sign in"
    And the rendered DOM has an input with name "username"
    And the rendered DOM has an input with name "password"

  Scenario: submitting the login form redirects to home
    Given the user is on the "/login" page
    When the user fills "username" with "alice"
    And the user fills "password" with "wonderland"
    And the user submits the form
    Then the final URL ends with "/"
    And the rendered HTML includes "shomer-ssr"
