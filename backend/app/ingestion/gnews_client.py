"""
GNews API client.

Fetches top financial headlines and normalises them into NormalizedArticle objects.
"""

from __future__ import annotations

import logging
from datetime import datetime

import httpx

from app.config import get_settings
from app.models.article import NormalizedArticle

logger = logging.getLogger(__name__)
settings = get_settings()

GNEWS_BASE_URL = "https://gnews.io/api/v4"

# Financial search topics to rotate through
FINANCIAL_TOPICS = [
    "stock market india",
    "NSE BSE",
    "RBI monetary policy",
    "indian economy",
    "sensex nifty",
    "finance india",
]


def _parse_datetime(dt_str: str | None) -> datetime | None:
    if not dt_str:
        return None
    try:
        return datetime.fromisoformat(dt_str.replace("Z", "+00:00"))
    except Exception:
        return None


def _normalize(raw: dict) -> NormalizedArticle:
    source = raw.get("source", {})
    return NormalizedArticle(
        headline=raw.get("title", ""),
        content=raw.get("content") or raw.get("description") or "",
        source=source.get("name") if isinstance(source, dict) else str(source),
        url=raw.get("url"),
        published_at=_parse_datetime(raw.get("publishedAt")),
        raw_json=raw,
    )


async def fetch_top_headlines(
    query: str = "finance india",
    max_results: int | None = None,
) -> list[NormalizedArticle]:
    """Fetch articles from GNews /search endpoint."""
    if max_results is None:
        max_results = settings.GNEWS_MAX_ARTICLES

    params = {
        "q": query,
        "lang": settings.GNEWS_LANG,
        "country": settings.GNEWS_COUNTRY,
        "max": max_results,
        "token": settings.GNEWS_API_KEY,
    }

    async with httpx.AsyncClient(timeout=30) as client:
        try:
            resp = await client.get(f"{GNEWS_BASE_URL}/search", params=params)
            resp.raise_for_status()
            data = resp.json()
            articles = data.get("articles", [])
            logger.info(
                "GNews returned %d articles for query '%s'", len(articles), query
            )
            return [_normalize(a) for a in articles]
        except httpx.HTTPStatusError as exc:
            logger.error(
                "GNews HTTP error: %s – %s", exc.response.status_code, exc.response.text
            )
            return []
        except Exception as exc:
            logger.error("GNews fetch failed: %s", exc)
            return []


async def fetch_all_topics() -> list[NormalizedArticle]:
    """Fetch articles across all configured financial topics, deduplicating by URL."""
    seen_urls: set[str] = set()
    results: list[NormalizedArticle] = []

    for topic in FINANCIAL_TOPICS:
        articles = await fetch_top_headlines(query=topic, max_results=10)
        for article in articles:
            if article.url and article.url not in seen_urls:
                seen_urls.add(article.url)
                results.append(article)

    logger.info("Total unique articles fetched: %d", len(results))
    return results
