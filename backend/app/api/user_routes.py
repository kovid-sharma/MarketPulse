"""
User-facing routes (authenticated).
"""

from __future__ import annotations


from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import get_current_user
from app.db.database import (
    get_db,
    list_articles,
    upsert_device_token,
    upsert_preferences,
)
from app.models.article import ArticleOut
from app.models.user import DeviceTokenPayload, UserDB, UserOut, UserPreferences

router = APIRouter(prefix="/users", tags=["User"])


@router.get("/me", response_model=UserOut)
async def get_me(current_user: UserDB = Depends(get_current_user)):
    """Return the current authenticated user's profile."""
    return current_user


@router.post("/preferences", status_code=204)
async def save_preferences(
    payload: UserPreferences,
    current_user: UserDB = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Save personalisation settings for the authenticated user."""
    await upsert_preferences(db, current_user.id, payload.model_dump())


@router.post("/device-token", status_code=204)
async def register_device_token(
    payload: DeviceTokenPayload,
    current_user: UserDB = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Register an FCM device token for push notifications."""
    await upsert_device_token(db, current_user.id, payload.token)


@router.get("/feed", response_model=list[ArticleOut])
async def get_feed(
    geography: str | None = Query(None),
    sentiment: str | None = Query(None),
    credibility: str | None = Query(None),
    sector: str | None = Query(None),
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: UserDB = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Personalised article feed.
    Explicit query params override saved preferences.
    """
    prefs = current_user.preferences or {}

    # Apply saved preferences as defaults when no explicit filter given
    effective_geography = geography or prefs.get("geography")
    effective_sentiment = sentiment
    effective_sector = sector or (
        prefs.get("sectors", [None])[0] if prefs.get("sectors") else None
    )

    return await list_articles(
        session=db,
        geography=effective_geography,
        credibility=credibility,
        sentiment=effective_sentiment,
        sector=effective_sector,
        limit=limit,
        offset=offset,
    )
