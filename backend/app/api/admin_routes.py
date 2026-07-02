"""
Admin-only routes.
All endpoints require role == "admin" via require_admin dependency.
"""

from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import require_admin
from app.db.database import (
    count_articles,
    create_article,
    get_article_by_id,
    get_db,
    get_user_by_id,
    list_review_articles,
    list_users,
    update_article_pipeline,
    update_user,
)
from app.models.article import ArticleManualCreate, ArticleOut, NormalizedArticle
from app.models.user import UserDB, UserOut, UserUpdate
from app.pipeline import queue as q
from app.pipeline.impact_mapper import get_impact_map, set_impact_map

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
