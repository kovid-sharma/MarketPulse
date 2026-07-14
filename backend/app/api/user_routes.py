"""
User-facing routes (authenticated).

New in this version:
  - /users/stocks/{symbol}      : Stock profile + vice-versa impact summary
  - /users/stocks/{symbol}/news : All news articles that affected a stock
  - /users/stocks               : Trending stocks by news activity
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import get_current_user
from app.db.database import (
    _ARTICLES,
    _STOCK_PROFILES,
    get_db,
    list_articles,
    upsert_device_token,
    upsert_preferences,
)
from app.models.article import ArticleOut
from app.models.user import DeviceTokenPayload, UserDB, UserOut, UserPreferences
from app.vector.opensearch_client import search_news_for_stock

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


# ── Stock Intelligence (Vice-Versa) ─────────────────────────────────────────────


@router.get("/stocks/{symbol}")
async def get_stock_profile(
    symbol: str,
    current_user: UserDB = Depends(get_current_user),
):
    """
    Get stock profile: name, sector, impact summary, training keywords.
    Powers the vice-versa Stock Intelligence screen in the user app.
    """
    sym = symbol.upper()
    profile = _STOCK_PROFILES.get(sym)

    article_count = sum(
        1 for art in _ARTICLES.values()
        if art.impacts and any(
            i.get("symbol", "").upper() == sym for i in art.impacts
        )
    )

    return {
        "symbol": sym,
        "name": profile.name if profile else sym,
        "sector": profile.sector if profile else None,
        "impact_summary": profile.impact_summary if profile else None,
        "training_keywords": profile.training_keywords if profile else [],
        "news_count": article_count,
        "last_trained_at": (
            profile.last_trained_at.isoformat()
            if profile and profile.last_trained_at else None
        ),
    }


@router.get("/stocks/{symbol}/news")
async def get_news_for_stock_user(
    symbol: str,
    limit: int = Query(20, ge=1, le=100),
    current_user: UserDB = Depends(get_current_user),
):
    """
    Vice-versa: all news articles that affected a given stock.
    Merges OpenSearch vector results with in-memory article store.
    """
    sym = symbol.upper()

    # Search OpenSearch
    vector_results = await search_news_for_stock(sym, k=limit)

    # Search in-memory DB for direct symbol matches
    db_matches = []
    for art in _ARTICLES.values():
        if (
            art.impacts
            and art.is_financially_relevant is True
            and art.ai_status == "done"
        ):
            symbols_in = [i.get("symbol", "").upper() for i in art.impacts]
            if sym in symbols_in:
                impact = next(
                    (i for i in art.impacts if i.get("symbol", "").upper() == sym),
                    {},
                )
                db_matches.append({
                    "article_id": str(art.id),
                    "headline": art.headline,
                    "summary": art.summary,
                    "content_snippet": (art.content or "")[:200],
                    "sector": impact.get("sector", ""),
                    "direction": impact.get("direction", "neutral"),
                    "effect": impact.get("effect", "medium"),
                    "reason": impact.get("reason", ""),
                    "sentiment": art.sentiment or "neutral",
                    "published_at": (
                        art.published_at.isoformat() if art.published_at else None
                    ),
                    "admin_verified": getattr(art, "vector_synced", False),
                    "source": art.source,
                    "url": art.url,
                })

    # Merge + deduplicate
    seen_ids: set[str] = set()
    merged = []
    for item in db_matches + vector_results:
        aid = item.get("article_id", "")
        if aid and aid not in seen_ids:
            seen_ids.add(aid)
            merged.append(item)

    merged.sort(key=lambda x: x.get("published_at") or "", reverse=True)

    return {"symbol": sym, "total": len(merged), "news": merged[:limit]}


@router.get("/stocks")
async def get_trending_stocks(
    limit: int = Query(20, ge=1, le=100),
    current_user: UserDB = Depends(get_current_user),
):
    """
    Trending stocks — stocks with the most recent news activity.
    Powers the Stocks tab in the user app.
    """
    stock_counts: dict[str, dict] = {}
    for art in _ARTICLES.values():
        if (
            art.impacts
            and art.is_financially_relevant is True
            and art.ai_status == "done"
        ):
            for imp in art.impacts:
                sym = imp.get("symbol", "").upper().strip()
                if not sym:
                    continue
                if sym not in stock_counts:
                    stock_counts[sym] = {
                        "symbol": sym,
                        "name": imp.get("name", sym),
                        "sector": imp.get("sector", ""),
                        "news_count": 0,
                        "latest_direction": imp.get("direction", "neutral"),
                        "latest_sentiment": art.sentiment or "neutral",
                        "latest_headline": art.headline,
                    }
                stock_counts[sym]["news_count"] += 1
                stock_counts[sym]["latest_direction"] = imp.get("direction", "neutral")
                stock_counts[sym]["latest_sentiment"] = art.sentiment or "neutral"
                stock_counts[sym]["latest_headline"] = art.headline

    sorted_stocks = sorted(stock_counts.values(), key=lambda x: -x["news_count"])
    return {
        "trending_stocks": sorted_stocks[:limit],
        "total_tracked": len(stock_counts),
    }
