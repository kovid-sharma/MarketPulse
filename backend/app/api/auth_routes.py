"""
Auth routes: login + register.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt_handler import create_access_token
from app.db.database import (
    create_user,
    get_db,
    get_user_by_email,
    verify_password,
)
from app.models.user import TokenResponse, UserCreate, UserLogin

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/register", response_model=TokenResponse, status_code=201)
async def register(payload: UserCreate, db: AsyncSession = Depends(get_db)):
    """Register a new user account."""
    existing = await get_user_by_email(db, payload.email)
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    # Only allow admin role if no other user exists yet (first user = bootstrap admin)
    from sqlalchemy import select, func
    from app.models.user import UserDB

    count_result = await db.execute(select(func.count()).select_from(UserDB))
    user_count = count_result.scalar_one()
    role = "admin" if user_count == 0 else payload.role

    db_user = await create_user(db, payload.email, payload.password, role)
    token = create_access_token(str(db_user.id), db_user.role)
    return TokenResponse(access_token=token, role=db_user.role, user_id=str(db_user.id))


@router.post("/login", response_model=TokenResponse)
async def login(payload: UserLogin, db: AsyncSession = Depends(get_db)):
    """Authenticate and receive a JWT token."""
    user = await get_user_by_email(db, payload.email)
    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is deactivated")

    token = create_access_token(str(user.id), user.role)
    return TokenResponse(access_token=token, role=user.role, user_id=str(user.id))
