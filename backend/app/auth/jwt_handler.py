"""
JWT token creation and verification.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from jose import jwt

from app.config import get_settings

settings = get_settings()


def create_access_token(user_id: str, role: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.JWT_EXPIRE_MINUTES)
    payload = {
        "sub": user_id,
        "role": role,
        "exp": expire,
    }
    return jwt.encode(
        payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM
    )


def decode_token(token: str) -> dict:
    """
    Raises jose.JWTError on invalid/expired token.
    Returns the decoded payload dict.
    """
    return jwt.decode(
        token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM]
    )
