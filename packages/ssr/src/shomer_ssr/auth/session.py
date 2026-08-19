# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Server-side sessions for the BFF.

WHY THE SESSION IS SERVER-SIDE AT ALL

The browser gets an opaque identifier and nothing else. Tokens, the PKCE
verifier and the nonce all stay here. A cross-site script that reads every
variable on the page finds no access token, because the page never had
one — which is the property the whole BFF pattern buys and the reason the
SPA is not simply doing the flow itself.

THE ROTATION ON LOGIN IS THE PART THAT IS EASY TO MISS

A session exists before the user authenticates: it holds the state, the
nonce and the verifier across the redirect. If that identifier survives
into the authenticated session, then anyone who could set the cookie
beforehand — a subdomain, a network position, a crafted link on a site
that shares the domain — is holding the identifier of a session that is
now logged in as the victim. That is session fixation, and it is invisible
in testing because everything works.

So `authenticate` mints a new identifier and destroys the old one. It is a
method rather than a convention because a convention is something the
fourth route forgets.
"""

from __future__ import annotations

import secrets
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass, field, replace
from typing import Any

# 32 bytes, URL-safe. `token_urlsafe(32)` yields 43 characters and 256
# bits — the same reasoning as the PKCE verifier: enough that guessing is
# not a strategy, and the identifier is opaque so length costs nothing.
_SESSION_ID_BYTES = 32

# A pre-authentication session only has to survive one trip to the IdP and
# back. Ten minutes is generous for a card reader or a two-factor prompt,
# and short enough that abandoned flows do not accumulate.
DEFAULT_PENDING_TTL_SECONDS = 600

# An authenticated session outlives the access token — it is what the
# refresh token is stored against. Eight hours is a working day, which is
# the unit that matters for a clinician who signed in this morning.
DEFAULT_SESSION_TTL_SECONDS = 8 * 3600


@dataclass(frozen=True, slots=True)
class PendingAuth:
    """What the callback will need to check itself against.

    Held here rather than in the browser because all three are things an
    attacker would love to choose: the state they will echo back, the
    nonce that binds the ID token, and the verifier that redeems the code.
    """

    state: str
    nonce: str
    verifier: str
    redirect_uri: str
    # Where to send the browser once the flow completes. Validated by the
    # caller before it gets here — an open redirect is the classic way a
    # login endpoint becomes a phishing tool.
    return_to: str = "/"


@dataclass(frozen=True, slots=True)
class Session:
    id: str
    created_at: float
    expires_at: float
    pending: PendingAuth | None = None
    # Tokens live here and nowhere else. Never serialised into a response.
    tokens: dict[str, Any] = field(default_factory=dict)
    claims: dict[str, Any] = field(default_factory=dict)
    csrf_token: str = ""

    @property
    def is_authenticated(self) -> bool:
        return bool(self.tokens)


class SessionStore(ABC):
    """Injectable, because production needs Redis and tests must not.

    An in-process dictionary is correct for one worker and silently wrong
    for two: a user's session lands on whichever worker answered, and every
    other one reports them signed out. Making the store an argument means
    that choice is made where the app is assembled rather than discovered
    under load.
    """

    @abstractmethod
    def get(self, session_id: str) -> Session | None:
        """Return the session, or None when it is absent or expired."""

    @abstractmethod
    def save(self, session: Session) -> None: ...

    @abstractmethod
    def delete(self, session_id: str) -> None:
        """Must succeed when there is nothing to delete."""


class InMemorySessionStore(SessionStore):
    """For development and tests. Not for more than one worker."""

    def __init__(self, clock: Any = time.time) -> None:
        self._sessions: dict[str, Session] = {}
        self._clock = clock

    def get(self, session_id: str) -> Session | None:
        session = self._sessions.get(session_id)
        if session is None:
            return None

        # Expiry is enforced on read rather than by a sweep. A sweep that
        # falls behind hands out sessions that should be gone; this cannot,
        # whatever else is happening to the process.
        if self._clock() >= session.expires_at:
            del self._sessions[session_id]
            return None

        return session

    def save(self, session: Session) -> None:
        self._sessions[session.id] = session

    def delete(self, session_id: str) -> None:
        self._sessions.pop(session_id, None)


def new_session_id() -> str:
    """A fresh, unguessable identifier."""
    return secrets.token_urlsafe(_SESSION_ID_BYTES)


class SessionManager:
    """Creates, rotates and ends sessions."""

    def __init__(
        self,
        store: SessionStore,
        clock: Any = time.time,
        pending_ttl_seconds: int = DEFAULT_PENDING_TTL_SECONDS,
        session_ttl_seconds: int = DEFAULT_SESSION_TTL_SECONDS,
    ) -> None:
        self._store = store
        self._clock = clock
        self._pending_ttl = pending_ttl_seconds
        self._session_ttl = session_ttl_seconds

    def begin(self, pending: PendingAuth) -> Session:
        """Start a pre-authentication session to survive the redirect."""
        now = self._clock()
        session = Session(
            id=new_session_id(),
            created_at=now,
            expires_at=now + self._pending_ttl,
            pending=pending,
            csrf_token=secrets.token_urlsafe(_SESSION_ID_BYTES),
        )
        self._store.save(session)
        return session

    def authenticate(
        self,
        session: Session,
        tokens: dict[str, Any],
        claims: dict[str, Any],
    ) -> Session:
        """Promote a pending session, under a NEW identifier.

        See the module docstring: reusing the identifier here is session
        fixation, and everything keeps working while it is wrong.
        """
        now = self._clock()
        promoted = Session(
            id=new_session_id(),
            created_at=now,
            expires_at=now + self._session_ttl,
            pending=None,
            tokens=tokens,
            claims=claims,
            # Rotated too. A CSRF token that survives the login is a token
            # the pre-authentication page could have learned.
            csrf_token=secrets.token_urlsafe(_SESSION_ID_BYTES),
        )
        self._store.save(promoted)
        # Deleted after the new one is stored: a crash between the two
        # should leave the user with a stale session rather than none.
        self._store.delete(session.id)
        return promoted

    def refresh_tokens(self, session: Session, tokens: dict[str, Any]) -> Session:
        """Replace the tokens, keeping the identifier.

        NOT rotated here. A refresh is not a change of principal, and
        rotating would invalidate the cookie every browser tab is holding
        — so an ordinary token renewal would sign the user out of every
        tab but the one that noticed first.
        """
        updated = replace(session, tokens=tokens)
        self._store.save(updated)
        return updated

    def end(self, session_id: str) -> None:
        self._store.delete(session_id)

    def load(self, session_id: str | None) -> Session | None:
        if not session_id:
            return None
        return self._store.get(session_id)
