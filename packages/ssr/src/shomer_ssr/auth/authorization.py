# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Building the authorization request, and reading the callback.

The Python counterpart of packages/lib/src/oidc/authorization-request.ts.
The rules are the same because the protocol is; where the two files differ
is only in what the language makes easy.

STATE AND NONCE DEFEND DIFFERENT THINGS, and conflating them is the
mistake this docstring exists to prevent:

  state  compared when the browser comes back. It ties the callback to the
         request this server started, which is what stops an attacker
         feeding us a code obtained in their own session — a login CSRF
         that ends with the victim signed in as the attacker.

  nonce  carried inside the ID token and compared after the exchange. It
         ties the token to this request, stopping an ID token minted for
         another session being replayed at us.

Reusing one value for both means a leak of the callback URL — a referrer
header, a proxy log — hands over the token binding as well.
"""

from __future__ import annotations

import secrets
from dataclasses import dataclass
from urllib.parse import parse_qsl, quote, urlsplit

from .pkce import PkcePair

# Same width as the PKCE verifier, and for the same reason: these are
# values an attacker would like to guess, and 256 bits is not guessable.
_TOKEN_BYTES = 32

# Parameters the caller may not supply through `extra`. Letting one
# through would be silent: a request with an attacker's code_challenge or
# redirect_uri is still well-formed, and looks right in every log.
_PROTOCOL_PARAMS = frozenset(
    {
        "response_type",
        "client_id",
        "redirect_uri",
        "scope",
        "state",
        "nonce",
        "code_challenge",
        "code_challenge_method",
    }
)


@dataclass(frozen=True, slots=True)
class AuthorizationRequest:
    url: str
    state: str
    nonce: str


def new_token() -> str:
    return secrets.token_urlsafe(_TOKEN_BYTES)


def build_authorization_url(
    *,
    authorization_endpoint: str,
    client_id: str,
    redirect_uri: str,
    scopes: tuple[str, ...],
    pkce: PkcePair,
    state: str,
    nonce: str,
    acr_values: tuple[str, ...] = (),
    prompt: str | None = None,
    max_age: int | None = None,
    extra: dict[str, str] | None = None,
) -> str:
    """Assemble the URL the browser is redirected to."""
    # `openid` is what makes this OIDC rather than plain OAuth2. Without
    # it the IdP returns no ID token, which surfaces much later as a
    # missing claim rather than as a bad request.
    ordered = scopes if "openid" in scopes else ("openid", *scopes)

    query: dict[str, str] = {
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "scope": " ".join(ordered),
        "state": state,
        "nonce": nonce,
        "code_challenge": pkce.challenge,
        "code_challenge_method": pkce.method,
    }

    if acr_values:
        # Pro Santé Connect reads this to demand an assurance level — the
        # card, or a strong second factor. An IdP that receives none may
        # satisfy the request with whatever session it already has.
        query["acr_values"] = " ".join(acr_values)
    if prompt is not None:
        query["prompt"] = prompt
    if max_age is not None:
        # Compared against None rather than truthiness: max_age=0 means
        # "re-authenticate now" and is a legitimate request, which a falsy
        # check would drop — turning a forced re-authentication into an
        # ordinary one that reuses the existing session.
        query["max_age"] = str(max_age)

    for key, value in (extra or {}).items():
        if key in _PROTOCOL_PARAMS:
            raise ValueError(
                f'extra parameter "{key}" would overwrite a protocol parameter'
            )
        query[key] = value

    encoded = "&".join(
        f"{quote(k, safe='')}={quote(v, safe='')}" for k, v in query.items()
    )
    # An endpoint may legitimately carry parameters already — some IdPs
    # publish one with a tenant baked in.
    separator = "&" if "?" in authorization_endpoint else "?"
    return f"{authorization_endpoint}{separator}{encoded}"


def create_authorization_request(
    *,
    authorization_endpoint: str,
    client_id: str,
    redirect_uri: str,
    scopes: tuple[str, ...],
    pkce: PkcePair,
    acr_values: tuple[str, ...] = (),
    prompt: str | None = None,
    max_age: int | None = None,
    extra: dict[str, str] | None = None,
) -> AuthorizationRequest:
    """Build the request and mint the two values the callback must match."""
    state = new_token()
    nonce = new_token()
    return AuthorizationRequest(
        url=build_authorization_url(
            authorization_endpoint=authorization_endpoint,
            client_id=client_id,
            redirect_uri=redirect_uri,
            scopes=scopes,
            pkce=pkce,
            state=state,
            nonce=nonce,
            acr_values=acr_values,
            prompt=prompt,
            max_age=max_age,
            extra=extra,
        ),
        state=state,
        nonce=nonce,
    )


@dataclass(frozen=True, slots=True)
class CallbackParams:
    code: str | None = None
    state: str | None = None
    error: str | None = None
    error_description: str | None = None


def parse_callback(query_string: str) -> CallbackParams:
    """Read the authorization response.

    FIRST OCCURRENCE WINS. An IdP sends each parameter once, so a second
    is somebody appending to the URL — and taking the last would let them
    override the state this server is about to compare against.
    `parse_qsl` returns them in order, so the first assignment is kept.
    """
    found: dict[str, str] = {}
    for key, value in parse_qsl(query_string, keep_blank_values=True):
        found.setdefault(key, value)

    return CallbackParams(
        code=found.get("code"),
        state=found.get("state"),
        error=found.get("error"),
        error_description=found.get("error_description"),
    )


def is_safe_return_to(target: str) -> bool:
    """Whether a post-login redirect target is one we may follow.

    THE OPEN REDIRECT IS THE CLASSIC WAY A LOGIN ENDPOINT BECOMES A
    PHISHING TOOL: `/auth/login?return_to=https://evil.example` sends the
    user through the real IdP, on the real domain, and then hands them to
    the attacker — with the whole flow looking legitimate because it was.

    Only same-site absolute paths are allowed. A scheme-relative `//host`
    is rejected explicitly: it has no scheme, reads as a path, and
    browsers treat it as an absolute URL.
    """
    if not target.startswith("/"):
        return False
    if target.startswith("//"):
        return False
    # A backslash is normalised to a forward slash by some browsers, so
    # `/\evil.example` is another way to write `//evil.example`.
    if target.startswith("/\\"):
        return False
    # urlsplit finds a scheme or a host if one is hiding in there.
    parts = urlsplit(target)
    return not parts.scheme and not parts.netloc
