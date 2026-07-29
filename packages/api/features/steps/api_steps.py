# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Step implementations for the shomer-api BDD suite.

The steps fall into three groups:

* setup — the Background `Given` confirms the service is reachable.
* action — `When I GET <path>` performs the request via the shared
  httpx client and stashes the response on the context.
* assertion — `Then` clauses validate status code and JSON payload
  shape. JSON-body assertions use a small regex/equality vocabulary
  rather than free-form lambdas so the .feature stays readable.
"""

from __future__ import annotations

import re

from behave import given, then, when


@given("shomer-api is reachable at SHOMER_API_URL")
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
# the longer steps below (`equal to "..."`, `matching "..."`,
# `containing "..."`), which is what behave's registration-time
# ambiguity check otherwise trips on with the default `{key}` =
# lazy `.+?`.
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


@then('the JSON body has key "{key}" containing "{element}"')
def step_key_contains(context, key, element):
    body = context.response.json()
    value = body.get(key)
    assert isinstance(value, list), f"{key} is not a list: {value!r}"
    assert element in value, f"{key}={value!r} does not contain {element!r}"
