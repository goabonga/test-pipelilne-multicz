# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

from urllib.parse import parse_qs, urlsplit

import pytest
from shomer_ssr.auth.authorization import (
    build_authorization_url,
    create_authorization_request,
    is_safe_return_to,
    parse_callback,
)
from shomer_ssr.auth.pkce import PkcePair

PKCE = PkcePair(verifier="kept-on-the-server", challenge="sent-to-the-idp")

BASE = {
    "authorization_endpoint": "https://psc.example/authorize",
    "client_id": "shomer",
    "redirect_uri": "https://app.example/auth/callback",
    "scopes": ("openid", "profile"),
    "pkce": PKCE,
}


def query_of(url: str) -> dict[str, list[str]]:
    return parse_qs(urlsplit(url).query, keep_blank_values=True)


def test_sends_the_challenge_and_never_the_verifier() -> None:
    # A verifier in the authorization request is a verifier in the
    # browser's history and the IdP's logs — PKCE undone while every
    # parameter still looks right.
    url = build_authorization_url(**BASE, state="st", nonce="no")

    assert query_of(url)["code_challenge"] == ["sent-to-the-idp"]
    assert query_of(url)["code_challenge_method"] == ["S256"]
    assert "kept-on-the-server" not in url


def test_state_and_nonce_are_different_values() -> None:
    # They defend different things, so sharing one means a leaked callback
    # URL hands over the token binding too.
    request = create_authorization_request(**BASE)

    assert request.state != request.nonce
    assert query_of(request.url)["state"] == [request.state]
    assert query_of(request.url)["nonce"] == [request.nonce]


def test_adds_openid_when_the_caller_forgot_it() -> None:
    # Without it the IdP runs plain OAuth2 and returns no ID token, which
    # surfaces later as a missing claim rather than as a bad request.
    url = build_authorization_url(
        **{**BASE, "scopes": ("profile",)}, state="s", nonce="n"
    )

    assert query_of(url)["scope"] == ["openid profile"]


def test_does_not_add_openid_twice() -> None:
    url = build_authorization_url(**BASE, state="s", nonce="n")

    assert query_of(url)["scope"] == ["openid profile"]


def test_carries_acr_values_for_an_assurance_level() -> None:
    # Pro Santé Connect reads this to demand the card or a strong second
    # factor.
    url = build_authorization_url(
        **BASE, state="s", nonce="n", acr_values=("eidas2", "eidas3")
    )

    assert query_of(url)["acr_values"] == ["eidas2 eidas3"]


def test_omits_optional_parameters_when_absent() -> None:
    # An empty acr_values is not the same as an absent one: some IdPs
    # reject the empty string rather than ignoring it.
    url = build_authorization_url(**BASE, state="s", nonce="n")
    query = query_of(url)

    assert "acr_values" not in query
    assert "prompt" not in query
    assert "max_age" not in query


def test_carries_prompt_when_a_step_up_is_forced() -> None:
    # `login` forces re-authentication even when the IdP has a live
    # session — the whole mechanism behind a step-up, and silently a no-op
    # if the parameter is dropped.
    url = build_authorization_url(**BASE, state="s", nonce="n", prompt="login")

    assert query_of(url)["prompt"] == ["login"]


def test_sends_max_age_of_zero_rather_than_treating_it_as_unset() -> None:
    # Zero means "re-authenticate now". A truthiness check would drop it,
    # turning a forced re-authentication into an ordinary one.
    url = build_authorization_url(**BASE, state="s", nonce="n", max_age=0)

    assert query_of(url)["max_age"] == ["0"]


def test_refuses_an_extra_that_would_overwrite_a_protocol_parameter() -> None:
    # THE assertion. An extra that replaced code_challenge would disable
    # PKCE, one that replaced redirect_uri would send the code elsewhere —
    # and the request would still look well-formed everywhere it is logged.
    with pytest.raises(ValueError, match="would overwrite a protocol parameter"):
        build_authorization_url(
            **BASE, state="s", nonce="n", extra={"code_challenge": "attacker"}
        )


def test_keeps_extras_that_do_not_collide() -> None:
    url = build_authorization_url(
        **BASE, state="s", nonce="n", extra={"tenant": "chu-lille"}
    )

    assert query_of(url)["tenant"] == ["chu-lille"]


def test_appends_to_an_endpoint_that_already_has_a_query() -> None:
    url = build_authorization_url(
        **{**BASE, "authorization_endpoint": "https://psc.example/authorize?v=2"},
        state="s",
        nonce="n",
    )

    assert query_of(url)["v"] == ["2"]
    assert query_of(url)["client_id"] == ["shomer"]


def test_escapes_values_rather_than_letting_them_break_the_query() -> None:
    # A redirect_uri contains :// and often a query of its own. Unescaped,
    # it truncates everything after it — including code_challenge.
    url = build_authorization_url(
        **{**BASE, "redirect_uri": "https://app.example/cb?next=/a&b=1"},
        state="s",
        nonce="n",
    )

    assert query_of(url)["redirect_uri"] == ["https://app.example/cb?next=/a&b=1"]
    assert query_of(url)["code_challenge"] == ["sent-to-the-idp"]


def test_parse_callback_reads_code_and_state() -> None:
    params = parse_callback("code=abc&state=xyz")

    assert params.code == "abc"
    assert params.state == "xyz"


def test_parse_callback_reads_an_idp_refusal() -> None:
    # Consent declined, or an acr_values the account cannot satisfy. The
    # IdP explained itself; a generic failure throws that away.
    params = parse_callback("error=access_denied&error_description=carte+absente")

    assert params.error == "access_denied"
    assert params.error_description == "carte absente"


def test_parse_callback_keeps_the_first_of_a_duplicate() -> None:
    # An IdP sends each parameter once, so a second is somebody appending
    # to the URL — and taking the last would let them override the state
    # about to be compared.
    params = parse_callback("state=real&state=injected")

    assert params.state == "real"


def test_parse_callback_on_an_empty_query() -> None:
    params = parse_callback("")

    assert params.code is None
    assert params.state is None


@pytest.mark.parametrize(
    "target",
    ["/", "/app", "/app/patients?id=1", "/a#b"],
)
def test_same_site_paths_are_safe(target: str) -> None:
    assert is_safe_return_to(target) is True


@pytest.mark.parametrize(
    "target",
    [
        "https://evil.example",
        "//evil.example",
        "/\\evil.example",
        "http://evil.example/x",
        "javascript:alert(1)",
        "app",
        "",
    ],
)
def test_anything_that_could_leave_the_site_is_refused(target: str) -> None:
    # THE assertion here. /auth/login?return_to=https://evil.example sends
    # the user through the real IdP on the real domain and then hands them
    # to the attacker — the whole flow looking legitimate because it was.
    #
    # //host has no scheme and reads as a path, but browsers treat it as
    # absolute. A backslash is normalised to a slash by some, so
    # /\evil.example is another spelling of the same attack.
    assert is_safe_return_to(target) is False
