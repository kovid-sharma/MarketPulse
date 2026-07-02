"""
User DB model + Pydantic schemas.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, EmailStr
from sqlalchemy import JSON, Boolean, Column, DateTime, String
from sqlalchemy.dialects.postgresql import UUID

from app.models.article import Base


# ── DB Model ──────────────────────────────────────────────────────────────────


class UserDB(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(256), unique=True, nullable=False, index=True)
    hashed_password = Column(String(256), nullable=False)
    role = Column(String(16), default="user", nullable=False)  # user | admin
    is_active = Column(Boolean, default=True)
    device_token = Column(String(512), nullable=True)  # FCM token
    preferences = Column(JSON, nullable=True)  # {sectors, geography, alerts}
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)


# ── Pydantic Schemas ──────────────────────────────────────────────────────────


class UserCreate(BaseModel):
    email: EmailStr
    password: str
    role: str = "user"


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    user_id: str


class UserOut(BaseModel):
    id: uuid.UUID
    email: str
    role: str
    is_active: bool
    preferences: dict[str, Any] | None
    created_at: datetime

    model_config = {"from_attributes": True}


class UserPreferences(BaseModel):
    sectors: list[str] = []
    geography: str | None = None  # "india" | "global" | None = both
    sentiments: list[str] = []  # ["bullish", "bearish", "neutral"]
    alert_threshold: str = "all"  # "all" | "high_impact"


class DeviceTokenPayload(BaseModel):
    token: str


class UserUpdate(BaseModel):
    role: str | None = None
    is_active: bool | None = None
