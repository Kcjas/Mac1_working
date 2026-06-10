# backend/security.py
"""Password hashing and JWT token utilities.

Centralizes all password handling so the rest of the app never touches
plaintext passwords or raw crypto primitives. Uses the `bcrypt` library,
which salts automatically and verifies in constant time (mitigating timing
attacks). Never implement hashing by hand.

Also issues and verifies the signed JWT access tokens used for API auth.
"""

import os
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from dotenv import load_dotenv

# Ensure JWT_SECRET (and other .env values) are available even if this module
# is imported before the DB layer loads the environment.
load_dotenv()

# --- JWT configuration -------------------------------------------------------
# HS256 secret MUST come from the environment in any real deployment. The
# fallback only keeps local dev from crashing; it is not a secure value.
JWT_SECRET = os.getenv("JWT_SECRET", "dev-insecure-change-me")
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 7

# bcrypt operates on at most 72 bytes of the password and silently ignores
# anything beyond that. We reject overly long inputs explicitly so two
# different long passwords can never collide on their first 72 bytes.
_MAX_PASSWORD_BYTES = 72


def hash_password(password: str) -> str:
    """Hash a plaintext password for storage.

    Returns a self-contained bcrypt hash string (algorithm, cost and salt are
    embedded in the output, so no separate salt column is needed).

    Raises ValueError for empty or excessively long passwords.
    """
    if not password:
        raise ValueError("Password must not be empty")

    pwd_bytes = password.encode("utf-8")
    if len(pwd_bytes) > _MAX_PASSWORD_BYTES:
        raise ValueError(
            f"Password must not exceed {_MAX_PASSWORD_BYTES} bytes"
        )

    hashed = bcrypt.hashpw(pwd_bytes, bcrypt.gensalt())
    return hashed.decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Check a plaintext password against a stored bcrypt hash.

    Returns False (never raises) on empty inputs or malformed hashes, so
    callers can treat any falsy result as "authentication failed".
    The underlying bcrypt.checkpw comparison is constant time.
    """
    if not plain_password or not hashed_password:
        return False

    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            hashed_password.encode("utf-8"),
        )
    except (ValueError, TypeError):
        # Malformed/legacy (e.g. plaintext) stored hash.
        return False


def create_access_token(user_id: int, role: str) -> str:
    """Issue a signed JWT for the given user.

    The token carries the user id (``sub``) and role purely for convenience;
    the server always re-reads the role from the database, never trusting the
    claim. Expires after ``ACCESS_TOKEN_EXPIRE_DAYS``.
    """
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "role": role,
        "iat": now,
        "exp": now + timedelta(days=ACCESS_TOKEN_EXPIRE_DAYS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> dict:
    """Verify a JWT and return its payload.

    The explicit ``algorithms`` allow-list is critical: it blocks the
    ``alg:none`` / algorithm-confusion attacks where a forged token declares a
    different (or no) signing algorithm. Raises ``jwt.PyJWTError`` (the base
    class for expired/invalid-signature/malformed) on any failure, which
    callers translate into a 401.
    """
    return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
