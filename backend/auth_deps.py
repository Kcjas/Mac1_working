# backend/auth_deps.py
"""FastAPI auth dependencies: token validation and role guards.

Kept in its own module (separate from the routers and from main.py) so any
router can depend on it without import cycles.
"""

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from .database import SessionLocal
from .models import User
from .security import decode_access_token

# auto_error=True → a missing/malformed Authorization header yields the
# stock 401 "Not authenticated" before our code even runs. The scheme name
# shown in OpenAPI is "HTTPBearer".
bearer = HTTPBearer()

_CREDENTIALS_EXCEPTION = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Invalid or expired token",
    headers={"WWW-Authenticate": "Bearer"},
)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
) -> User:
    """Resolve the authenticated user from a Bearer JWT.

    Verifies the signature, then loads the user from the database. The role
    used for authorization is always the DB value, never the token claim.
    """
    token = credentials.credentials
    try:
        payload = decode_access_token(token)
        user_id = int(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError, TypeError):
        raise _CREDENTIALS_EXCEPTION

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
    finally:
        db.close()

    if user is None:
        raise _CREDENTIALS_EXCEPTION
    return user


def require_role(*roles: str):
    """Build a dependency that requires the current user to hold one of ``roles``.

    Role is read from the DB-backed user (see get_current_user), so a tampered
    role claim is irrelevant — and an invalid signature is rejected first.
    """

    def _guard(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to perform this action",
            )
        return user

    return _guard


require_admin = require_role("admin")
require_worker = require_role("worker")
require_customer = require_role("customer")
