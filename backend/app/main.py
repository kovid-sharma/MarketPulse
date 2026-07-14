"""
MarketPulse – FastAPI entrypoint.

Startup sequence:
  1. Initialise DB (create tables)
  2. Start queue worker (processes articles through the full pipeline)
  3. Start GNews polling scheduler
"""

from __future__ import annotations

import asyncio
import logging
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Any

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.admin_routes import ingestion_state
from app.api.admin_routes import router as admin_router
from app.api.auth_routes import router as auth_router
from app.api.routes import router as articles_router
from app.api.user_routes import router as user_router
from app.config import get_settings
from app.db.database import (
    AsyncSessionLocal,
    create_article,
    get_article_by_url,
    init_db,
    update_article_pipeline,
)
from app.ingestion.gnews_client import fetch_all_topics
from app.models.article import NormalizedArticle
from app.pipeline import queue as q
from app.pipeline.classifier import classify_article
from app.pipeline.enrichment import enrich_article
from app.pipeline.finance_filter import is_financially_relevant
from app.pipeline.impact_mapper import map_impact
from app.vector.opensearch_client import setup_indices
from app.vector.sync_worker import sync_article_to_vector_store

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s – %(message)s"
)
logger = logging.getLogger(__name__)
settings = get_settings()


# ── Pipeline handler ──────────────────────────────────────────────────────────


async def process_article(article_id: uuid.UUID) -> None:
    """Full pipeline: filter → classify → impact → enrich → store."""
    async with AsyncSessionLocal() as session:
        from app.db.database import get_article_by_id

        db_article = await get_article_by_id(session, article_id)
        if not db_article:
            logger.warning("Article %s not found in DB – skipping", article_id)
            return

        article = NormalizedArticle(
            headline=db_article.headline,
            content=db_article.content,
            source=db_article.source,
            url=db_article.url,
            published_at=db_article.published_at,
        )

        updates: dict[str, Any] = {}

        # ── Step 1: Finance filter ────────────────────────────────────────────
        try:
            is_relevant, reason = await is_financially_relevant(article)
        except Exception as exc:
            logger.error("Finance filter error for %s: %s", article_id, exc)
            ingestion_state["error_count"] += 1
            await update_article_pipeline(session, article_id, {"ai_status": "failed"})
            return

        updates["is_financially_relevant"] = is_relevant
        updates["finance_filter_reason"] = reason

        if not is_relevant:
            updates["ai_status"] = "done"
            await update_article_pipeline(session, article_id, updates)
            logger.info("Article %s dropped by finance filter: %s", article_id, reason)
            return

        # ── Step 2: Classification ────────────────────────────────────────────
        try:
            classification = await classify_article(article)
            updates["credibility"] = classification.credibility
            updates["geography"] = classification.geography
            updates["classification_confidence"] = classification.confidence
            updates["needs_review"] = classification.needs_review
        except Exception as exc:
            logger.error("Classifier error for %s: %s", article_id, exc)
            ingestion_state["error_count"] += 1

        # ── Step 3: Impact mapping ────────────────────────────────────────────
        try:
            text = f"{article.headline} {article.content or ''}"
            impacts = map_impact(text)
            updates["impacts"] = impacts
        except Exception as exc:
            logger.error("Impact mapper error for %s: %s", article_id, exc)

        # ── Step 4: Enrichment ────────────────────────────────────────────────
        try:
            enrichment = await enrich_article(article)
            updates["summary"] = enrichment.summary
            updates["context"] = enrichment.context
            updates["impact_explanation"] = enrichment.impact_explanation
            updates["key_takeaway"] = enrichment.key_takeaway
            updates["sentiment"] = enrichment.sentiment
            updates["markets_affected"] = enrichment.markets_affected
            updates["trade_logic"] = enrichment.trade_logic

            # Prefer Gemini's structured stock_impacts over keyword-based impacts
            # if Gemini returned meaningful data; otherwise fall back to keyword mapper
            if enrichment.stock_impacts:
                updates["impacts"] = enrichment.stock_impacts
            # else: keep the keyword-based impacts already set in updates["impacts"]

            updates["ai_status"] = "done"
        except Exception as exc:
            logger.error("Enrichment error for %s: %s", article_id, exc)
            ingestion_state["error_count"] += 1
            updates["ai_status"] = "failed"

        await update_article_pipeline(session, article_id, updates)
        logger.info(
            "Article %s pipeline complete – status: %s",
            article_id,
            updates.get("ai_status"),
        )

        # ── Step 5: Vector sync to AWS OpenSearch (non-blocking) ────────────────
        if updates.get("ai_status") == "done":
            try:
                impacts = updates.get("impacts") or []
                synced = await sync_article_to_vector_store(
                    article_id=str(article_id),
                    headline=article.headline,
                    content=article.content,
                    impacts=impacts,
                    sentiment=updates.get("sentiment"),
                    published_at=(
                        article.published_at.isoformat()
                        if article.published_at else None
                    ),
                    admin_verified=False,
                )
                if synced:
                    await update_article_pipeline(
                        session,
                        article_id,
                        {
                            "vector_synced": True,
                            "vector_synced_at": datetime.now(timezone.utc),
                        },
                    )
                    logger.info("Article %s synced to AWS OpenSearch vector store", article_id)
            except Exception as vec_exc:
                logger.warning("Vector sync failed for %s (non-fatal): %s", article_id, vec_exc)


# ── GNews polling job ─────────────────────────────────────────────────────────


async def poll_gnews() -> None:
    """Fetch latest articles from GNews, deduplicate, persist, and enqueue."""
    logger.info("GNews poll started")
    articles = await fetch_all_topics()

    async with AsyncSessionLocal() as session:
        for article in articles:
            if article.url:
                existing = await get_article_by_url(session, article.url)
                if existing:
                    continue

            db_article = await create_article(session=session, article=article)
            await q.enqueue(db_article.id)
            logger.debug("Enqueued article: %s", db_article.id)

    ingestion_state["last_ingestion_time"] = datetime.now(timezone.utc).isoformat()
    logger.info("GNews poll finished. Queue size: %d", q.qsize())


# ── App lifecycle ─────────────────────────────────────────────────────────────


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    logger.info("Database initialised")

    # Set up AWS OpenSearch vector indices (non-blocking if AWS not configured)
    try:
        loop = asyncio.get_event_loop()
        ok = await loop.run_in_executor(None, setup_indices)
        if ok:
            logger.info("AWS OpenSearch Serverless indices ready")
        else:
            logger.info("AWS OpenSearch not configured – vector features disabled")
    except Exception as os_exc:
        logger.warning("OpenSearch setup failed (non-fatal): %s", os_exc)

    worker_task = asyncio.create_task(q.run_worker(process_article))

    scheduler = AsyncIOScheduler()
    scheduler.add_job(
        poll_gnews,
        "interval",
        minutes=settings.GNEWS_POLL_INTERVAL_MINUTES,
        id="gnews_poll",
        replace_existing=True,
    )
    scheduler.start()
    logger.info(
        "Scheduler started – polling every %d minutes",
        settings.GNEWS_POLL_INTERVAL_MINUTES,
    )

    asyncio.create_task(poll_gnews())

    yield

    scheduler.shutdown(wait=False)
    worker_task.cancel()
    logger.info("Shutdown complete")


# ── FastAPI app ───────────────────────────────────────────────────────────────

app = FastAPI(
    title="MarketPulse API",
    description="AI-powered financial news ingestion, classification, and enrichment pipeline",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(articles_router)
app.include_router(user_router)
app.include_router(admin_router)


@app.get("/", tags=["Health"])
async def root():
    return {"status": "ok", "service": "MarketPulse API", "version": "2.0.0"}


@app.get("/health", tags=["Health"])
async def health():
    return {"status": "healthy", "queue_size": q.qsize()}
