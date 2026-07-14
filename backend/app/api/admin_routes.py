"""
Admin-only routes.
All endpoints require role == "admin" via require_admin dependency.

New in this version:
  - /admin/vector/*            : Vector training management (AWS OpenSearch)
  - /admin/articles/{id}/train : Admin manually updates stock associations + syncs to vector store
  - /admin/stocks/*            : Vice-versa stock profile management
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import require_admin
from app.db.database import (
    _STOCK_PROFILES,
    count_articles,
    create_article,
    get_article_by_id,
    get_db,
    get_user_by_id,
    list_articles_pending_vector_sync,
    list_articles_vector_synced,
    list_review_articles,
    list_users,
    update_article_pipeline,
    update_user,
)
from app.models.article import ArticleManualCreate, ArticleOut, NormalizedArticle
from app.models.stock_profile import (
    ArticleVectorUpdate,
    StockProfileCreate,
    StockProfileDB,
    StockProfileOut,
    StockProfileUpdate,
)
from app.models.user import UserDB, UserOut, UserUpdate
from app.pipeline import queue as q
from app.pipeline.impact_mapper import get_impact_map, set_impact_map
from app.vector.opensearch_client import (
    get_index_stats,
    search_news_for_stock,
    update_article_stocks,
)
from app.vector.sync_worker import sync_article_to_vector_store

router = APIRouter(prefix="/admin", tags=["Admin"])


# ── Health ────────────────────────────────────────────────────────────────────

# Module-level state updated by main.py during ingestion
ingestion_state: dict[str, Any] = {
    "last_ingestion_time": None,
    "error_count": 0,
    "articles_today": 0,
}


@router.get("/health")
async def admin_health(
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(require_admin),
):
    """System health: queue size, last ingestion, error counts, article totals."""
    total = await count_articles(db)
    return {
        "status": "healthy",
        "queue_size": q.qsize(),
        "last_ingestion_time": ingestion_state.get("last_ingestion_time"),
        "error_count": ingestion_state.get("error_count", 0),
        "total_articles": total,
    }


# ── Article review ────────────────────────────────────────────────────────────


@router.get("/articles/review", response_model=list[ArticleOut])
async def get_review_queue(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(require_admin),
):
    """List articles flagged needs_review = true (low confidence classification)."""
    return await list_review_articles(db, limit=limit, offset=offset)


@router.patch("/articles/{article_id}/review")
async def review_article(
    article_id: uuid.UUID,
    action: str = Query(..., description="approve | reject"),
    credibility: str | None = Query(
        None, description="Override credibility: confirmed | opinion"
    ),
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(require_admin),
):
    """Admin approve or reject a low-confidence article."""
    article = await get_article_by_id(db, article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Article not found")

    if action == "approve":
        data: dict[str, Any] = {"needs_review": False}
        if credibility:
            data["credibility"] = credibility
        await update_article_pipeline(db, article_id, data)
        return {"status": "approved", "id": str(article_id)}
    elif action == "reject":
        await update_article_pipeline(
            db,
            article_id,
            {
                "needs_review": False,
                "is_financially_relevant": False,
                "ai_status": "rejected",
            },
        )
        return {"status": "rejected", "id": str(article_id)}
    else:
        raise HTTPException(
            status_code=400, detail="action must be 'approve' or 'reject'"
        )


@router.post("/articles/manual", response_model=ArticleOut, status_code=201)
async def manual_article_admin(
    payload: ArticleManualCreate,
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(require_admin),
):
    """Admin manual article entry — saved and enqueued for full pipeline."""
    normalized = NormalizedArticle(
        headline=payload.headline,
        content=payload.content,
        source=payload.source,
        url=payload.url,
        published_at=payload.published_at,
    )
    db_article = await create_article(session=db, article=normalized)
    await q.enqueue(db_article.id)
    return db_article


# ── Vector Training ──────────────────────────────────────────────────────────


@router.get("/vector/stats")
async def vector_stats(_: UserDB = Depends(require_admin)):
    """AWS OpenSearch vector index statistics."""
    stats = await get_index_stats()
    pending_count = len([
        a for a in list(__import__("app.db.database", fromlist=["_ARTICLES"])._ARTICLES.values())
        if a.ai_status == "done"
        and a.is_financially_relevant is True
        and not getattr(a, "vector_synced", False)
        and a.impacts
    ])
    return {
        **stats,
        "pending_sync_count": pending_count,
        "stock_profiles_count": len(_STOCK_PROFILES),
    }


@router.get("/vector/pending", response_model=list[ArticleOut])
async def get_pending_vector_articles(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(require_admin),
):
    """Articles that have been AI-processed but not yet synced to vector store."""
    return await list_articles_pending_vector_sync(db, limit=limit, offset=offset)


@router.get("/vector/synced", response_model=list[ArticleOut])
async def get_synced_vector_articles(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(require_admin),
):
    """Articles already synced to the AWS OpenSearch vector store."""
    return await list_articles_vector_synced(db, limit=limit, offset=offset)


@router.post("/vector/train/{article_id}")
async def manually_sync_article_to_vector(
    article_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(require_admin),
):
    """
    Admin manually triggers vector sync for a specific article.
    Useful for resyncing after admin edits stock associations.
    """
    article = await get_article_by_id(db, article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Article not found")

    if not article.impacts:
        raise HTTPException(status_code=422, detail="Article has no stock impacts to sync")

    synced = await sync_article_to_vector_store(
        article_id=str(article_id),
        headline=article.headline,
        content=article.content,
        impacts=article.impacts,
        sentiment=article.sentiment,
        published_at=article.published_at.isoformat() if article.published_at else None,
        admin_verified=True,  # Admin-triggered = verified
    )

    if synced:
        await update_article_pipeline(
            db,
            article_id,
            {
                "vector_synced": True,
                "vector_synced_at": datetime.now(timezone.utc),
            },
        )
        return {"status": "synced", "article_id": str(article_id), "admin_verified": True}
    else:
        return {
            "status": "skipped",
            "article_id": str(article_id),
            "reason": "AWS OpenSearch not configured or embedding failed",
        }


@router.post("/vector/train-all")
async def sync_all_pending_articles(
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(require_admin),
):
    """Bulk sync all pending articles to the vector store."""
    pending = await list_articles_pending_vector_sync(db, limit=200)
    synced_count = 0
    failed_count = 0

    for article in pending:
        try:
            ok = await sync_article_to_vector_store(
                article_id=str(article.id),
                headline=article.headline,
                content=article.content,
                impacts=article.impacts,
                sentiment=article.sentiment,
                published_at=article.published_at.isoformat() if article.published_at else None,
                admin_verified=False,
            )
            if ok:
                await update_article_pipeline(
                    db, article.id,
                    {"vector_synced": True, "vector_synced_at": datetime.now(timezone.utc)},
                )
                synced_count += 1
            else:
                failed_count += 1
        except Exception:
            failed_count += 1

    return {
        "status": "complete",
        "synced": synced_count,
        "failed": failed_count,
        "total_processed": len(pending),
    }


# ── Article stock association (admin training) ─────────────────────────────────


@router.patch("/articles/{article_id}/train-stocks")
async def update_article_stock_training(
    article_id: uuid.UUID,
    payload: ArticleVectorUpdate,
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(require_admin),
):
    """
    Admin updates a news article's stock associations and marks them as admin-verified.
    This updates:
      1. The article's impacts in the DB
      2. The OpenSearch vector document (admin_verified=True)
      3. Re-syncs the embedding to reflect the admin correction
    """
    article = await get_article_by_id(db, article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Article not found")

    # Build updated impacts from payload
    symbols = [s.upper().strip() for s in payload.stock_symbols if s.strip()]
    names = payload.stock_names or symbols

    new_impacts = [
        {
            "symbol": sym,
            "name": names[i] if i < len(names) else sym,
            "sector": payload.sector,
            "direction": payload.direction,
            "effect": "high",
            "reason": f"Admin-verified: directly affected by this news ({payload.sector} sector).",
        }
        for i, sym in enumerate(symbols)
    ]

    # Update DB
    await update_article_pipeline(
        db,
        article_id,
        {"impacts": new_impacts, "vector_synced": False},
    )

    # Update OpenSearch vector document
    await update_article_stocks(
        article_id=str(article_id),
        stock_symbols=symbols,
        stock_names=names,
        sector=payload.sector,
        direction=payload.direction,
        admin_verified=True,
    )

    # Re-sync with admin_verified=True
    synced = await sync_article_to_vector_store(
        article_id=str(article_id),
        headline=article.headline,
        content=article.content,
        impacts=new_impacts,
        sentiment=article.sentiment,
        published_at=article.published_at.isoformat() if article.published_at else None,
        admin_verified=True,
    )

    if synced:
        await update_article_pipeline(
            db, article_id,
            {"vector_synced": True, "vector_synced_at": datetime.now(timezone.utc)},
        )

    return {
        "status": "updated",
        "article_id": str(article_id),
        "stock_symbols": symbols,
        "admin_verified": True,
        "vector_synced": synced,
    }


# ── Stock profiles (vice-versa) ───────────────────────────────────────────────


@router.get("/stocks", response_model=list[StockProfileOut])
async def list_stock_profiles(_: UserDB = Depends(require_admin)):
    """List all admin-created stock training profiles."""
    return list(_STOCK_PROFILES.values())


@router.get("/stocks/{symbol}/news")
async def get_news_for_stock(
    symbol: str,
    k: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(require_admin),
):
    """
    Vice-versa: get all news articles that affected a stock symbol.
    Searches the AWS OpenSearch vector store + in-memory article store.
    """
    symbol_upper = symbol.upper()

    # Search OpenSearch vector store
    vector_results = await search_news_for_stock(symbol_upper, k=k)

    # Also search in-memory DB for direct matches
    from app.db.database import _ARTICLES
    db_matches = []
    for art in _ARTICLES.values():
        if art.impacts:
            symbols_in_article = [i.get("symbol", "").upper() for i in art.impacts]
            if symbol_upper in symbols_in_article:
                impact = next((i for i in art.impacts if i.get("symbol", "").upper() == symbol_upper), {})
                db_matches.append({
                    "article_id": str(art.id),
                    "headline": art.headline,
                    "content_snippet": (art.content or "")[:200],
                    "sector": impact.get("sector", ""),
                    "direction": impact.get("direction", "neutral"),
                    "sentiment": art.sentiment or "neutral",
                    "published_at": art.published_at.isoformat() if art.published_at else None,
                    "admin_verified": getattr(art, "vector_synced", False),
                    "effect": impact.get("effect", "medium"),
                    "reason": impact.get("reason", ""),
                })

    # Merge, deduplicate by article_id (prefer vector store results)
    seen_ids = set()
    merged = []
    for item in vector_results + db_matches:
        aid = item.get("article_id", "")
        if aid and aid not in seen_ids:
            seen_ids.add(aid)
            merged.append(item)

    return {
        "symbol": symbol_upper,
        "profile": _STOCK_PROFILES.get(symbol_upper),
        "news_count": len(merged),
        "news": merged[:k],
    }


@router.post("/stocks/profile", response_model=StockProfileOut, status_code=201)
async def create_stock_profile(
    payload: StockProfileCreate,
    _: UserDB = Depends(require_admin),
):
    """Create or update a stock training profile."""
    symbol = payload.symbol.upper().strip()

    profile = StockProfileDB(
        symbol=symbol,
        name=payload.name or symbol,
        sector=payload.sector,
        training_keywords=payload.training_keywords,
        related_article_ids=payload.related_article_ids,
        impact_summary=payload.impact_summary,
        last_trained_at=datetime.now(timezone.utc),
        vector_id=symbol,
    )
    _STOCK_PROFILES[symbol] = profile
    return profile


@router.patch("/stocks/{symbol}/profile", response_model=StockProfileOut)
async def update_stock_profile(
    symbol: str,
    payload: StockProfileUpdate,
    _: UserDB = Depends(require_admin),
):
    """Update an existing stock training profile."""
    sym = symbol.upper()
    profile = _STOCK_PROFILES.get(sym)
    if not profile:
        raise HTTPException(status_code=404, detail="Stock profile not found")

    updates = payload.model_dump(exclude_none=True)
    for k, v in updates.items():
        setattr(profile, k, v)
    profile.last_trained_at = datetime.now(timezone.utc)
    return profile


# ── User management ───────────────────────────────────────────────────────────


@router.get("/users", response_model=list[UserOut])
async def admin_list_users(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(require_admin),
):
    """List all registered users."""
    return await list_users(db, limit=limit, offset=offset)


@router.patch("/users/{user_id}", response_model=UserOut)
async def admin_update_user(
    user_id: uuid.UUID,
    payload: UserUpdate,
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(require_admin),
):
    """Update a user's role or active status."""
    user = await get_user_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    updates = payload.model_dump(exclude_none=True)
    if not updates:
        return user
    return await update_user(db, user_id, updates)


# ── Impact mapping config ─────────────────────────────────────────────────────


@router.get("/config/impact-mapping")
async def get_impact_mapping(_: UserDB = Depends(require_admin)):
    """Return current in-memory keyword → impact mapping."""
    return get_impact_map()


@router.put("/config/impact-mapping")
async def update_impact_mapping(
    payload: dict[str, Any],
    _: UserDB = Depends(require_admin),
):
    """
    Replace the in-memory impact mapping at runtime.
    Changes are live immediately but not persisted to disk (restart resets to code defaults).
    Future phase will persist to DB.
    """
    set_impact_map(payload)
    return {"status": "updated", "entries": len(payload)}
