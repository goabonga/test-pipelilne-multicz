# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""PKCE — RFC 7636. The Python half.

WHY THIS EXISTS ALONGSIDE packages/lib/src/oidc/pkce.ts

The mobile client is TypeScript and the BFF is Python. They speak the same
protocol to the same IdP, so the same rules are implemented twice, and two
implementations of a security protocol can drift apart silently — one
accepting what the other refuses, with nothing failing until an IdP
disagrees with whichever half is wrong.

The mitigation is that BOTH suites assert the worked example from RFC 7636
Appendix B: one published verifier, one required challenge. Neither can
drift without failing against the document every IdP implements against,
which is a stronger guarantee than testing them against each other.

The standard library covers all of it — `secrets`, `hashlib`, `base64` —
so this adds no dependency, which is the point of writing it rather than
importing an OIDC library.

S256 ONLY, for the same reason as the TypeScript side: `plain` sends the
verifier as the challenge and protects against nobody who can read the
authorization request.
"""

from __future__ import annotations

import base64
import hashlib
import secrets
from dataclasses import dataclass

# RFC 7636 §4.1 allows 43–128 characters. 32 random bytes base64url-encode
# to exactly 43 — the shortest the spec permits and already 256 bits.
# Longer buys nothing: the challenge is a SHA-256 digest either way, so
# entropy past the hash width is discarded.
_VERIFIER_BYTES = 32


@dataclass(frozen=True, slots=True)
class PkcePair:
    """Kept apart deliberately: only one of these may leave the server."""

    verifier: str
    challenge: str
    method: str = "S256"


def base64url_encode(data: bytes) -> str:
    """RFC 4648 §5 — the base64 alphabet with -/_ and no padding.

    The padding matters. `=` is not valid in a code_challenge and IdPs
    differ in whether they reject it or silently mismatch, which is the
    worse outcome: the flow fails at the token exchange with an error
    about the verifier rather than about the encoding.
    """
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def create_pkce_pair() -> PkcePair:
    """A fresh pair.

    ONE PER AUTHORIZATION REQUEST. Reusing a verifier means anyone who
    obtains it once can complete every later exchange, which turns PKCE
    from a defence into a long-lived secret.
    """
    verifier = base64url_encode(secrets.token_bytes(_VERIFIER_BYTES))
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    return PkcePair(verifier=verifier, challenge=base64url_encode(digest))


def challenge_for(verifier: str) -> str:
    """The challenge a given verifier produces.

    Exposed so a test can assert the RFC's worked example directly, and so
    a caller can re-derive rather than store both halves.
    """
    return base64url_encode(hashlib.sha256(verifier.encode("ascii")).digest())
