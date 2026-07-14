"""
StockProfile SQLAlchemy model and Pydantic schemas.

Persists admin-curated stock training data to the database so it
survives application restarts. OpenSearch has the vector copy;
this DB table is the source of truth for admin edits.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel
from sqlalchemy import Column, DateTime, JSON, String, Text
from sqlalchemy.orm import DeclarativeBase

from app.models.article import Base  # re-use the same declarative base


class StockProfileDB(Base):
    """Database-persisted stock training profile."""

    __tablename__ = "stock_profiles"

    symbol = Column(String(32), primary_key=True)  # e.g. HDFCBANK
    name = Column(String(256), nullable=True)
    sector = Column(String(128), nullable=True)
    training_keywords = Column(JSON, nullable=True)    # list[str] — keywords that trigger this stock
    related_article_ids = Column(JSON, nullable=True)  # list[str UUID] — articles linked to this stock
    impact_summary = Column(Text, nullable=True)       # AI/admin generated summary of why stock reacts
    last_trained_at = Column(DateTime(timezone=True), nullable=True)
    vector_id = Column(String(256), nullable=True)     # OpenSearch document ID (= symbol.upper())


# ── Pydantic schemas ───────────────────────────────────────────────────────────


class StockProfileBase(BaseModel):
    symbol: str
    name: str | None = None
    sector: str | None = None
    training_keywords: list[str] = []
    impact_summary: str | None = None


class StockProfileCreate(StockProfileBase):
    related_article_ids: list[str] = []


class StockProfileUpdate(BaseModel):
    name: str | None = None
    sector: str | None = None
    training_keywords: list[str] | None = None
    related_article_ids: list[str] | None = None
    impact_summary: str | None = None


class StockProfileOut(StockProfileBase):
    related_article_ids: list[str] = []
    last_trained_at: datetime | None = None
    vector_id: str | None = None

    model_config = {"from_attributes": True}


class ArticleVectorUpdate(BaseModel):
    """Admin payload to manually update a news article's stock associations."""
    stock_symbols: list[str]
    stock_names: list[str] = []
    sector: str = "broad market"
    direction: str = "neutral"  # positive | negative | neutral
