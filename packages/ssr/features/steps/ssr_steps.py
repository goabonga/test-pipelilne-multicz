# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Step implementations for the shomer-ssr BDD suite.

Two step vocabularies live side by side:

* HTTP — `Given shomer-ssr is reachable`, `When I GET`, and the
  `Then JSON body …` family used by health.feature. Mirrors the api
  side's shape so a future shared step library can absorb them
  without rename churn.
* Browser — `When the user navigates`, `… fills … with …`,
  `… submits the form`, `Then the page title contains`, plus the DOM
  / URL assertions for ui.feature. All driven by Playwright via
  ``context.page``.
"""

from __future__ import annotations

import re

from behave import given, then, when

# --- HTTP steps ------------------------------------------------------


@given("shomer-ssr is reachable at SHOMER_SSR_URL")
def step_reachable(context):
    response = context.client.get("/healthz")
    assert response.status_code == 200, (
        f"liveness check failed against {context.base_url}: "
        f"status={response.status_code} body={response.text!r}"
    )


@when('I GET "{path}"')
def step_get(context, path):
    context.response = context.client.get(path)


@then("the response status is {status:d}")
def step_status(context, status):
    assert context.response.status_code == status, (
        f"unexpected status: got {context.response.status_code} "
        f"want {status} (body={context.response.text!r})"
    )


# {key:S} = non-whitespace match (built-in parse type). Stops the
# pattern's regex from greedily absorbing the trailing qualifier of
# the longer steps below (`equal to "..."`, `matching "..."`), which
# is what behave's registration-time ambiguity check otherwise trips
# on with the default `{key}` = lazy `.+?`.
@then('the JSON body has key "{key:S}"')
def step_has_key(context, key):
    body = context.response.json()
    assert key in body, f"missing key {key!r} in body {body!r}"


@then('the JSON body has key "{key}" equal to "{value}"')
def step_key_equals(context, key, value):
    body = context.response.json()
    assert body.get(key) == value, f"{key}: got {body.get(key)!r} want {value!r}"


@then('the JSON body has key "{key}" matching "{pattern}"')
def step_key_matches(context, key, pattern):
    body = context.response.json()
    value = body.get(key)
    assert isinstance(value, str), f"{key} is not a string: {value!r}"
    assert re.match(pattern, value), f"{key}={value!r} does not match /{pattern}/"


# --- Browser steps (Playwright) -------------------------------------


@when('the user navigates to "{path}"')
def step_navigate(context, path):
    context.page.goto(path, wait_until="networkidle")


@given('the user is on the "{path}" page')
def step_user_on(context, path):
    context.page.goto(path, wait_until="networkidle")


@when('the user fills "{name}" with "{value}"')
def step_fill(context, name, value):
    context.page.locator(f'input[name="{name}"]').fill(value)


@when("the user submits the form")
def step_submit(context):
    # Prefer an explicit submit button when present; fall back to
    # pressing Enter inside the last filled input, which is what an
    # end user typically does on a single-field-of-focus form.
    submit = context.page.locator('button[type="submit"], input[type="submit"]')
    if submit.count() > 0:
        with context.page.expect_navigation(wait_until="networkidle"):
            submit.first.click()
    else:
        with context.page.expect_navigation(wait_until="networkidle"):
            context.page.keyboard.press("Enter")


@then('the page title contains "{needle}"')
def step_title_contains(context, needle):
    title = context.page.title()
    assert needle in title, f"page title {title!r} does not contain {needle!r}"


@then('the rendered HTML includes "{needle}"')
def step_html_includes(context, needle):
    html = context.page.content()
    assert needle in html, f"rendered HTML does not include {needle!r}"


@then('the rendered DOM has an input with name "{name}"')
def step_input_present(context, name):
    locator = context.page.locator(f'input[name="{name}"]')
    assert locator.count() >= 1, f"no <input name={name!r}> in the rendered DOM"


@then('the final URL ends with "{suffix}"')
def step_url_ends_with(context, suffix):
    url = context.page.url
    assert url.endswith(suffix), f"final URL {url!r} does not end with {suffix!r}"
