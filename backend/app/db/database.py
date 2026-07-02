"""
PostgreSQL connection + CRUD helpers using SQLAlchemy async.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from passlib.context import CryptContext
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import get_settings
from app.models.article import ArticleDB, Base, NormalizedArticle
from app.models.user import UserDB

settings = get_settings()

# ── Password hashing ──────────────────────────────────────────────────────────

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


# ── Engine ────────────────────────────────────────────────────────────────────

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
    pool_pre_ping=True,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    expire_on_commit=False,
    class_=AsyncSession,
)


async def init_db() -> None:
    """Create all tables if they don't exist."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


# ── Session dependency ────────────────────────────────────────────────────────


async def get_db():
    async with AsyncSessionLocal() as session:
        yield session


# ── Article CRUD ──────────────────────────────────────────────────────────────


async def create_article(
    session: AsyncSession,
    article: NormalizedArticle,
) -> ArticleDB:
    db_article = ArticleDB(
        headline=article.headline,
        content=article.content,
        source=article.source,
        url=article.url,
        published_at=article.published_at,
        raw_json=article.raw_json,
        fetched_at=datetime.utcnow(),
        ai_status="pending",
    )
    session.add(db_article)
    await session.commit()
    await session.refresh(db_article)
    return db_article


async def get_article_by_url(session: AsyncSession, url: str) -> ArticleDB | None:
    result = await session.execute(select(ArticleDB).where(ArticleDB.url == url))
    return result.scalars().first()


async def get_article_by_id(
    session: AsyncSession, article_id: uuid.UUID
) -> ArticleDB | None:
    result = await session.execute(select(ArticleDB).where(ArticleDB.id == article_id))
    return result.scalars().first()


async def list_articles(
    session: AsyncSession,
    geography: str | None = None,
    credibility: str | None = None,
    sentiment: str | None = None,
    sector: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> list[ArticleDB]:
    q = select(ArticleDB).where(ArticleDB.is_financially_relevant == True)  # noqa: E712
    if geography:
        q = q.where(ArticleDB.geography == geography)
    if credibility:
        q = q.where(ArticleDB.credibility == credibility)
    if sentiment:
        q = q.where(ArticleDB.sentiment == sentiment)
    # sector filter: checks JSON impacts array contains an object with matching sector
    if sector:
        from sqlalchemy import cast
        from sqlalchemy.dialects.postgresql import JSONB

        q = q.where(
            ArticleDB.impacts.cast(JSONB).contains(cast([{"sector": sector}], JSONB))
        )
    q = q.order_by(ArticleDB.published_at.desc()).limit(limit).offset(offset)
    result = await session.execute(q)
    return list(result.scalars().all())


async def list_review_articles(
    session: AsyncSession,
    limit: int = 50,
    offset: int = 0,
) -> list[ArticleDB]:
    q = (
        select(ArticleDB)
        .where(ArticleDB.needs_review == True)  # noqa: E712
        .order_by(ArticleDB.fetched_at.desc())
        .limit(limit)
        .offset(offset)
    )
    result = await session.execute(q)
    return list(result.scalars().all())


async def update_article_pipeline(
    session: AsyncSession,
    article_id: uuid.UUID,
    data: dict[str, Any],
) -> None:
    await session.execute(
        update(ArticleDB).where(ArticleDB.id == article_id).values(**data)
    )
    await session.commit()


async def count_articles(session: AsyncSession) -> int:
    from sqlalchemy import func

    result = await session.execute(select(func.count()).select_from(ArticleDB))
    return result.scalar_one()


# ── User CRUD ─────────────────────────────────────────────────────────────────


async def create_user(
    session: AsyncSession,
    email: str,
    password: str,
    role: str = "user",
) -> UserDB:
    db_user = UserDB(
        email=email.lower().strip(),
        hashed_password=hash_password(password),
        role=role,
    )
    session.add(db_user)
    await session.commit()
    await session.refresh(db_user)
    return db_user


async def get_user_by_email(session: AsyncSession, email: str) -> UserDB | None:
    result = await session.execute(
        select(UserDB).where(UserDB.email == email.lower().strip())
    )
    return result.scalars().first()


async def get_user_by_id(session: AsyncSession, user_id: uuid.UUID) -> UserDB | None:
    result = await session.execute(select(UserDB).where(UserDB.id == user_id))
    return result.scalars().first()


async def list_users(
    session: AsyncSession,
    limit: int = 50,
    offset: int = 0,
) -> list[UserDB]:
    result = await session.execute(
        select(UserDB).order_by(UserDB.created_at.desc()).limit(limit).offset(offset)
    )
    return list(result.scalars().all())


async def update_user(
    session: AsyncSession,
    user_id: uuid.UUID,
    data: dict[str, Any],
) -> UserDB | None:
    await session.execute(update(UserDB).where(UserDB.id == user_id).values(**data))
    await session.commit()
    return await get_user_by_id(session, user_id)


async def upsert_device_token(
    session: AsyncSession,
    user_id: uuid.UUID,
    token: str,
) -> None:
    await session.execute(
        update(UserDB).where(UserDB.id == user_id).values(device_token=token)
    )
    await session.commit()


async def upsert_preferences(
    session: AsyncSession,
    user_id: uuid.UUID,
    prefs: dict[str, Any],
) -> None:
    await session.execute(
        update(UserDB).where(UserDB.id == user_id).values(preferences=prefs)
    )
    await session.commit()
