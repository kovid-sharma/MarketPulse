"""
PostgreSQL connection + CRUD helpers using SQLAlchemy async (mocked in-memory).
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

import bcrypt

from app.models.article import ArticleDB, Base, NormalizedArticle
from app.models.user import UserDB
from app.models.stock_profile import StockProfileDB

# ── Password hashing ──────────────────────────────────────────────────────────


def hash_password(password: str) -> str:
    # Hash password using bcrypt directly
    pwd_bytes = password.encode("utf-8")
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(pwd_bytes, salt)
    return hashed.decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False



# ── Global In-Memory Stores ───────────────────────────────────────────────────

_USERS: dict[uuid.UUID, UserDB] = {}
_ARTICLES: dict[uuid.UUID, ArticleDB] = {}
_STOCK_PROFILES: dict[str, StockProfileDB] = {}  # keyed by symbol.upper()


# Seed default credentials immediately
def _seed_default_users():
    admin_id = uuid.uuid4()
    admin_user = UserDB(
        id=admin_id,
        email="admin@marketpulse.com",
        hashed_password=hash_password("admin123"),
        role="admin",
        is_active=True,
        created_at=datetime.utcnow(),
    )
    
    user_id = uuid.uuid4()
    regular_user = UserDB(
        id=user_id,
        email="user@marketpulse.com",
        hashed_password=hash_password("user123"),
        role="user",
        is_active=True,
        created_at=datetime.utcnow(),
    )
    
    _USERS[admin_id] = admin_user
    _USERS[user_id] = regular_user


_seed_default_users()


# ── Mock Database Session / Engine ───────────────────────────────────────────

class MockResult:
    def __init__(self, val: Any):
        self.val = val

    def scalar_one(self) -> Any:
        return self.val

    def scalars(self) -> MockResult:
        return self

    def first(self) -> Any:
        if isinstance(self.val, list):
            return self.val[0] if self.val else None
        return self.val

    def all(self) -> Any:
        return self.val


class MockSession:
    async def execute(self, statement: Any, *args: Any, **kwargs: Any) -> MockResult:
        # Handles select(func.count()).select_from(UserDB) used to check if DB is empty
        stmt_str = str(statement).lower()
        if "count" in stmt_str:
            if "users" in stmt_str:
                return MockResult(len(_USERS))
            if "articles" in stmt_str:
                return MockResult(len(_ARTICLES))
        return MockResult(None)

    def add(self, obj: Any) -> None:
        if isinstance(obj, UserDB):
            _USERS[obj.id] = obj
        elif isinstance(obj, ArticleDB):
            _ARTICLES[obj.id] = obj

    async def commit(self) -> None:
        pass

    async def refresh(self, obj: Any) -> None:
        pass

    async def close(self) -> None:
        pass

    async def __aenter__(self) -> MockSession:
        return self

    async def __aexit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> None:
        pass


def AsyncSessionLocal() -> MockSession:
    return MockSession()


async def get_db():
    async with MockSession() as session:
        yield session


async def init_db() -> None:
    """Create all tables (no-op in-memory)."""
    pass


# ── Article CRUD ──────────────────────────────────────────────────────────────


async def create_article(
    session: Any,
    article: NormalizedArticle,
) -> ArticleDB:
    db_article = ArticleDB(
        id=uuid.uuid4(),
        headline=article.headline,
        content=article.content,
        source=article.source,
        url=article.url,
        published_at=article.published_at or datetime.utcnow(),
        fetched_at=datetime.utcnow(),
        is_financially_relevant=None,
        finance_filter_reason=None,
        needs_review=False,
        ai_status="pending",
        raw_json=article.raw_json,
    )
    _ARTICLES[db_article.id] = db_article
    return db_article


async def get_article_by_url(session: Any, url: str) -> ArticleDB | None:
    for art in _ARTICLES.values():
        if art.url == url:
            return art
    return None


async def get_article_by_id(
    session: Any, article_id: uuid.UUID
) -> ArticleDB | None:
    return _ARTICLES.get(article_id)


async def list_articles(
    session: Any,
    geography: str | None = None,
    credibility: str | None = None,
    sentiment: str | None = None,
    sector: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> list[ArticleDB]:
    results = []
    for art in _ARTICLES.values():
        if art.is_financially_relevant is not True:
            continue
        if geography and art.geography != geography:
            continue
        if credibility and art.credibility != credibility:
            continue
        if sentiment and art.sentiment != sentiment:
            continue
        if sector:
            # Check if any impact matches the sector
            has_sector = False
            if art.impacts:
                for imp in art.impacts:
                    if imp.get("sector") == sector:
                        has_sector = True
                        break
            if not has_sector:
                continue
        results.append(art)
    
    results.sort(key=lambda x: x.published_at or datetime.min, reverse=True)
    return results[offset : offset + limit]


async def list_review_articles(
    session: Any,
    limit: int = 50,
    offset: int = 0,
) -> list[ArticleDB]:
    results = [art for art in _ARTICLES.values() if art.needs_review is True]
    results.sort(key=lambda x: x.fetched_at or datetime.min, reverse=True)
    return results[offset : offset + limit]


async def update_article_pipeline(
    session: Any,
    article_id: uuid.UUID,
    data: dict[str, Any],
) -> None:
    art = _ARTICLES.get(article_id)
    if art:
        for k, v in data.items():
            setattr(art, k, v)


async def count_articles(session: Any) -> int:
    return len(_ARTICLES)


async def list_articles_pending_vector_sync(
    session: Any,
    limit: int = 50,
    offset: int = 0,
) -> list[ArticleDB]:
    """Articles that finished the AI pipeline but haven't been synced to OpenSearch."""
    results = [
        art for art in _ARTICLES.values()
        if art.ai_status == "done"
        and art.is_financially_relevant is True
        and not getattr(art, "vector_synced", False)
        and art.impacts
    ]
    results.sort(key=lambda x: x.fetched_at or datetime.min, reverse=True)
    return results[offset : offset + limit]


async def list_articles_vector_synced(
    session: Any,
    limit: int = 50,
    offset: int = 0,
) -> list[ArticleDB]:
    """Articles already synced to the vector store."""
    results = [
        art for art in _ARTICLES.values()
        if getattr(art, "vector_synced", False)
    ]
    results.sort(key=lambda x: getattr(x, "vector_synced_at", None) or datetime.min, reverse=True)
    return results[offset : offset + limit]


# ── User CRUD ─────────────────────────────────────────────────────────────────


async def create_user(
    session: Any,
    email: str,
    password: str,
    role: str = "user",
) -> UserDB:
    db_user = UserDB(
        id=uuid.uuid4(),
        email=email.lower().strip(),
        hashed_password=hash_password(password),
        role=role,
        is_active=True,
        created_at=datetime.utcnow(),
    )
    _USERS[db_user.id] = db_user
    return db_user


async def get_user_by_email(session: Any, email: str) -> UserDB | None:
    email_clean = email.lower().strip()
    for usr in _USERS.values():
        if usr.email == email_clean:
            return usr
    return None


async def get_user_by_id(session: Any, user_id: uuid.UUID) -> UserDB | None:
    return _USERS.get(user_id)


async def list_users(
    session: Any,
    limit: int = 50,
    offset: int = 0,
) -> list[UserDB]:
    results = list(_USERS.values())
    results.sort(key=lambda x: x.created_at or datetime.min, reverse=True)
    return results[offset : offset + limit]


async def update_user(
    session: Any,
    user_id: uuid.UUID,
    data: dict[str, Any],
) -> UserDB | None:
    usr = _USERS.get(user_id)
    if usr:
        for k, v in data.items():
            setattr(usr, k, v)
    return usr


async def upsert_device_token(
    session: Any,
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
