# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

from shomer_ssr.auth.session import (
    InMemorySessionStore,
    PendingAuth,
    SessionManager,
    new_session_id,
)


class FakeClock:
    """Time under test control, so expiry can be asserted without waiting."""

    def __init__(self, now: float = 1_760_000_000.0) -> None:
        self.now = now

    def __call__(self) -> float:
        return self.now

    def advance(self, seconds: float) -> None:
        self.now += seconds


def pending() -> PendingAuth:
    return PendingAuth(
        state="st", nonce="no", verifier="ve", redirect_uri="https://app/cb"
    )


def test_session_ids_are_unguessable() -> None:
    # An identifier short enough to guess makes every other control here
    # decorative — the session is the only thing standing between a
    # request and somebody else's tokens.
    ids = {new_session_id() for _ in range(200)}

    assert len(ids) == 200
    assert all(len(i) >= 43 for i in ids)


def test_begin_stores_what_the_callback_will_check() -> None:
    clock = FakeClock()
    manager = SessionManager(InMemorySessionStore(clock), clock)

    session = manager.begin(pending())

    loaded = manager.load(session.id)
    assert loaded is not None
    assert loaded.pending is not None
    assert loaded.pending.state == "st"
    assert loaded.pending.verifier == "ve"
    assert not loaded.is_authenticated


def test_authenticate_rotates_the_identifier() -> None:
    # THE assertion in this file. A pre-authentication session exists
    # before the user proves anything, so anyone who could set that cookie
    # beforehand — a subdomain, a crafted link — would be holding the
    # identifier of a session that is now logged in as the victim.
    #
    # It is invisible in testing because everything works.
    clock = FakeClock()
    manager = SessionManager(InMemorySessionStore(clock), clock)
    before = manager.begin(pending())

    after = manager.authenticate(before, {"access_token": "a"}, {"sub": "u"})

    assert after.id != before.id
    assert manager.load(before.id) is None
    assert manager.load(after.id) is not None


def test_authenticate_rotates_the_csrf_token_too() -> None:
    # A CSRF token that survives the login is a token the pre-login page
    # could have learned.
    clock = FakeClock()
    manager = SessionManager(InMemorySessionStore(clock), clock)
    before = manager.begin(pending())

    after = manager.authenticate(before, {"access_token": "a"}, {})

    assert after.csrf_token != before.csrf_token
    assert after.csrf_token


def test_authenticate_clears_the_pending_state() -> None:
    # Leaving it would keep a spent verifier on the server, and a state
    # that a later callback could still match.
    clock = FakeClock()
    manager = SessionManager(InMemorySessionStore(clock), clock)

    after = manager.authenticate(manager.begin(pending()), {"access_token": "a"}, {})

    assert after.pending is None
    assert after.is_authenticated


def test_a_pending_session_expires_quickly() -> None:
    # It only has to survive one trip to the IdP. Abandoned flows should
    # not accumulate.
    clock = FakeClock()
    manager = SessionManager(InMemorySessionStore(clock), clock)
    session = manager.begin(pending())

    clock.advance(601)

    assert manager.load(session.id) is None


def test_an_authenticated_session_lasts_a_working_day() -> None:
    clock = FakeClock()
    manager = SessionManager(InMemorySessionStore(clock), clock)
    session = manager.authenticate(manager.begin(pending()), {"access_token": "a"}, {})

    clock.advance(7 * 3600)
    assert manager.load(session.id) is not None

    clock.advance(2 * 3600)
    assert manager.load(session.id) is None


def test_expiry_is_enforced_on_read() -> None:
    # Rather than by a sweep. A sweep that falls behind hands out sessions
    # that should be gone; this cannot, whatever else the process is doing.
    clock = FakeClock()
    store = InMemorySessionStore(clock)
    manager = SessionManager(store, clock)
    session = manager.begin(pending())

    clock.advance(10_000)

    assert store.get(session.id) is None


def test_refreshing_tokens_keeps_the_identifier() -> None:
    # A refresh is not a change of principal. Rotating would invalidate the
    # cookie every open tab is holding, so an ordinary renewal would sign
    # the user out of every tab but the one that noticed first.
    clock = FakeClock()
    manager = SessionManager(InMemorySessionStore(clock), clock)
    session = manager.authenticate(manager.begin(pending()), {"access_token": "a"}, {})

    refreshed = manager.refresh_tokens(session, {"access_token": "b"})

    assert refreshed.id == session.id
    assert refreshed.tokens == {"access_token": "b"}
    loaded = manager.load(session.id)
    assert loaded is not None
    assert loaded.tokens == {"access_token": "b"}


def test_ending_a_session_removes_it() -> None:
    clock = FakeClock()
    manager = SessionManager(InMemorySessionStore(clock), clock)
    session = manager.begin(pending())

    manager.end(session.id)

    assert manager.load(session.id) is None


def test_ending_a_session_twice_is_not_an_error() -> None:
    # Sign-out has to be idempotent: a double-clicked button, a retried
    # request, a tab that already signed out.
    manager = SessionManager(InMemorySessionStore())

    manager.end("never-existed")
    manager.end("never-existed")


def test_loading_without_a_cookie_reports_no_session() -> None:
    # An absent cookie is an anonymous visitor, not an error.
    manager = SessionManager(InMemorySessionStore())

    assert manager.load(None) is None
    assert manager.load("") is None
    assert manager.load("not-a-real-id") is None
