"""
Configuration loader for MarketPulse backend.
Reads all settings from environment variables / .env file.
"""

from functools import lru_cache
from typing import Any
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # ── API Keys ─────────────────────────────────────────────────────────────
    GNEWS_API_KEY: str
    GEMINI_API_KEY: str

    # ── Database ──────────────────────────────────────────────────────────────
    DATABASE_URL: str  # e.g. postgresql+asyncpg://user:pass@host/db

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def validate_database_url(cls, v: Any) -> Any:
        if isinstance(v, str):
            # Normalize schemes to postgresql+asyncpg for SQLAlchemy compatibility
            if v.startswith("postgres://"):
                v = v.replace("postgres://", "postgresql+asyncpg://", 1)
            elif v.startswith("postgresql://") and not v.startswith("postgresql+asyncpg://"):
                v = v.replace("postgresql://", "postgresql+asyncpg://", 1)
            # Normalize sslmode=require to ssl=require for asyncpg compatibility
            if "sslmode=require" in v:
                v = v.replace("sslmode=require", "ssl=require")
        return v

    # ── GNews polling ────────────────────────────────────────────────────────
    GNEWS_POLL_INTERVAL_MINUTES: int = 5
    GNEWS_MAX_ARTICLES: int = 10  # articles per API call (max 10 free)
    GNEWS_LANG: str = "en"
    GNEWS_COUNTRY: str = "in"  # 'in' = India

    # ── Pipeline ─────────────────────────────────────────────────────────────
    GEMINI_MODEL: str = "gemini-2.0-flash"
    GEMINI_MAX_RETRIES: int = 3
    FINANCE_FILTER_CONFIDENCE_THRESHOLD: float = 0.6

    # ── JWT Auth ─────────────────────────────────────────────────────────────
    JWT_SECRET_KEY: str = "change-me-in-production-use-a-long-random-string"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 10080  # 7 days

    # ── Redis (optional, for future use) ─────────────────────────────────────
    REDIS_URL: str | None = None

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
