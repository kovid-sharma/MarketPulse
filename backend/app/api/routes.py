"""
REST API routes — public article endpoints (require auth).
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import get_current_user
from app.db.database import (
    create_article,
    get_article_by_id,
    get_db,
    list_articles,
)
from app.models.article import ArticleManualCreate, ArticleOut, NormalizedArticle
from app.models.user import UserDB
from app.pipeline import queue as q

router = APIRouter(prefix="/articles", tags=["Articles"])


@router.get("", response_model=list[ArticleOut])
async def get_articles(
    geography: str | None = Query(
        None, description="Filter by geography: india | global"
    ),
    credibility: str | None = Query(
        None, description="Filter by credibility: confirmed | opinion"
    ),
    sentiment: str | None = Query(
        None, description="Filter by sentiment: bullish | bearish | neutral"
    ),
    sector: str | None = Query(
        None, description="Filter by sector keyword (e.g. banking, it, pharma)"
    ),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(get_current_user),
):
    """List processed financial articles with optional filters."""
    articles = await list_articles(
        session=db,
        geography=geography,
        credibility=credibility,
        sentiment=sentiment,
        sector=sector,
        limit=limit,
        offset=offset,
    )
    return articles


@router.get("/{article_id}", response_model=ArticleOut)
async def get_article(
    article_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(get_current_user),
):
    """Retrieve a single article by ID."""
    article = await get_article_by_id(session=db, article_id=article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Article not found")
    return article


@router.post("/manual", response_model=ArticleOut, status_code=201)
async def manual_article(
    payload: ArticleManualCreate,
    db: AsyncSession = Depends(get_db),
    _: UserDB = Depends(get_current_user),
):
    """
    Manually submit an article for processing.
    The article will be saved, then enqueued for the full AI pipeline.
    """
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
