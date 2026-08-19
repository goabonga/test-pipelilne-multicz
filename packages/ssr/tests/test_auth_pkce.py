# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""PKCE, including the vector that keeps the two implementations honest.

`test_matches_the_rfc_worked_example` below is the same assertion as the
one in packages/lib/tests/oidc/pkce.test.ts, against the same published
values. Two implementations of one protocol can drift apart silently;
anchoring both to the specification rather than to each other means
neither can move without failing.
"""

from shomer_ssr.auth.pkce import base64url_encode, challenge_for, create_pkce_pair


def test_matches_the_rfc_worked_example() -> None:
    # RFC 7636 Appendix B. The TypeScript suite asserts this exact pair.
    verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

    assert challenge_for(verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"


def test_uses_the_url_alphabet_without_padding() -> None:
    # `=` is not valid in a code_challenge, and IdPs differ in whether they
    # reject it or silently mismatch — the second being worse, since the
    # flow then fails at the token exchange with an error about the
    # verifier rather than about the encoding.
    encoded = base64url_encode(bytes([0xFB, 0xFF, 0xFE]))

    assert encoded == "-__-"
    assert "+" not in encoded
    assert "/" not in encoded
    assert "=" not in encoded


def test_encodes_lengths_that_are_not_a_multiple_of_three() -> None:
    assert base64url_encode(b"a") == "YQ"
    assert base64url_encode(b"ab") == "YWI"
    assert base64url_encode(b"abc") == "YWJj"


def test_verifier_is_the_length_the_rfc_allows() -> None:
    pair = create_pkce_pair()

    # 43 to 128 characters, per §4.1.
    assert len(pair.verifier) == 43
    assert all(c.isalnum() or c in "-._~" for c in pair.verifier)


def test_only_offers_s256() -> None:
    pair = create_pkce_pair()

    assert pair.method == "S256"
    assert pair.challenge != pair.verifier


def test_the_challenge_is_the_hash_of_the_verifier() -> None:
    pair = create_pkce_pair()

    assert pair.challenge == challenge_for(pair.verifier)


def test_never_repeats_a_pair() -> None:
    # A reused verifier means whoever obtains it once can complete every
    # later exchange.
    pairs = [create_pkce_pair() for _ in range(50)]

    assert len({p.verifier for p in pairs}) == 50
    assert len({p.challenge for p in pairs}) == 50
