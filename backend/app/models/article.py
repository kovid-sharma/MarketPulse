"""
Article Pydantic + SQLAlchemy models.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel
from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    DateTime,
    Float,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase


# ── SQLAlchemy base ───────────────────────────────────────────────────────────


class Base(DeclarativeBase):
    pass


# ── DB Model ──────────────────────────────────────────────────────────────────


class ArticleDB(Base):
    __tablename__ = "articles"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    headline = Column(String(512), nullable=False)
    content = Column(Text, nullable=True)
    source = Column(String(256), nullable=True)
    url = Column(String(2048), nullable=True, unique=True)
    published_at = Column(DateTime(timezone=True), nullable=True)
    fetched_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    # Pipeline flags
    is_financially_relevant = Column(Boolean, nullable=True)
    finance_filter_reason = Column(Text, nullable=True)
    needs_review = Column(Boolean, default=False)
    ai_status = Column(String(32), default="pending")  # pending | done | failed

    # Classification
    credibility = Column(String(32), nullable=True)  # confirmed | opinion
    geography = Column(String(32), nullable=True)  # india | global
    classification_confidence = Column(Float, nullable=True)

    # Impact mapping
    impacts = Column(JSON, nullable=True)  # list of {sector, stocks, direction, effect, symbol}

    # AI enrichment
    summary = Column(Text, nullable=True)
    context = Column(Text, nullable=True)
    impact_explanation = Column(Text, nullable=True)
    key_takeaway = Column(Text, nullable=True)
    sentiment = Column(String(16), nullable=True)  # bullish | bearish | neutral
    markets_affected = Column(JSON, nullable=True)  # list of market/sector strings
    trade_logic = Column(Text, nullable=True)  # Gemini reasoning for the trade

    # Raw
    raw_json = Column(JSON, nullable=True)

    # Vector store sync
    vector_synced = Column(Boolean, default=False)
    vector_synced_at = Column(DateTime(timezone=True), nullable=True)


# ── Pydantic schemas ──────────────────────────────────────────────────────────


class CredibilityEnum(str, Enum):
    confirmed = "confirmed"
    opinion = "opinion"


class GeographyEnum(str, Enum):
    india = "india"
    global_ = "global"


class SentimentEnum(str, Enum):
    bullish = "bullish"
    bearish = "bearish"
    neutral = "neutral"


class ArticleBase(BaseModel):
    headline: str
    content: str | None = None
    source: str | None = None
    url: str | None = None
    published_at: datetime | None = None


class ArticleCreate(ArticleBase):
    raw_json: dict[str, Any] | None = None


class ArticleManualCreate(ArticleBase):
    """For POST /articles/manual"""

    pass


class ArticleOut(ArticleBase):
    id: uuid.UUID
    fetched_at: datetime
    is_financially_relevant: bool | None
    needs_review: bool
    ai_status: str
    credibility: CredibilityEnum | None
    geography: GeographyEnum | None
    classification_confidence: float | None
    impacts: list[dict[str, Any]] | None
    summary: str | None
    context: str | None
    impact_explanation: str | None
    key_takeaway: str | None
    sentiment: SentimentEnum | None
    markets_affected: list[str] | None = None
    trade_logic: str | None = None
    vector_synced: bool = False
    vector_synced_at: datetime | None = None

    model_config = {"from_attributes": True}


class NormalizedArticle(BaseModel):
    """Internal representation passing through the pipeline."""

    headline: str
    content: str | None = None
    source: str | None = None
    url: str | None = None
    published_at: datetime | None = None
    raw_json: dict[str, Any] | None = None
