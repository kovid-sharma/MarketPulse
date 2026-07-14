"""
Vector sync worker for MarketPulse.

After the AI pipeline finishes enriching an article, this module:
  1. Embeds the article text via AWS Bedrock Titan
  2. Indexes it into OpenSearch news_vectors (news → stocks)
  3. For each affected stock, updates the stock_vectors index (stock → news)

This creates the bidirectional link that powers:
  - RAG context injection for future articles
  - Vice-versa "which news affects this stock" feature in the user app
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Optional

from app.vector.bedrock_embedder import embed_text
from app.vector.opensearch_client import index_article, upsert_stock_profile, search_news_for_stock

logger = logging.getLogger(__name__)


async def sync_article_to_vector_store(
    article_id: str,
    headline: str,
    content: Optional[str],
    impacts: Optional[list[dict[str, Any]]],
    sentiment: Optional[str],
    published_at: Optional[str],
    admin_verified: bool = False,
) -> bool:
    """
    Embed and index an article into OpenSearch.
    Also updates per-stock vector profiles for the vice-versa feature.

    Returns True if successfully indexed.
    """
    if not impacts:
        logger.debug("Article %s has no impacts – skipping vector sync", article_id)
        return False

    # Build text for embedding
    embed_input = f"{headline}. {(content or '')[:2000]}"

    vector = await embed_text(embed_input)
    if vector is None:
        logger.warning("Could not generate embedding for article %s – AWS Bedrock unavailable", article_id)
        return False

    # Aggregate stock info from impacts
    stock_symbols: list[str] = []
    stock_names: list[str] = []
    sectors: list[str] = []
    directions: list[str] = []

    for imp in impacts:
        sym = str(imp.get("symbol", "")).upper().strip()
        if sym and sym not in stock_symbols:
            stock_symbols.append(sym)
            stock_names.append(str(imp.get("name", sym)))
            sec = str(imp.get("sector", ""))
            if sec:
                sectors.append(sec)
            dir_ = str(imp.get("direction", "neutral"))
            if dir_:
                directions.append(dir_)

    if not stock_symbols:
        logger.debug("Article %s has impacts but no stock symbols – skipping", article_id)
        return False

    # Determine dominant sector and direction
    sector = sectors[0] if sectors else "broad market"
    direction = _majority(directions) if directions else "neutral"

    # Index into news_vectors
    doc_id = await index_article(
        article_id=article_id,
        headline=headline,
        content=content or "",
        vector=vector,
        stock_symbols=stock_symbols,
        stock_names=stock_names,
        sector=sector,
        direction=direction,
        sentiment=sentiment or "neutral",
        published_at=published_at,
        admin_verified=admin_verified,
    )

    if doc_id is None:
        return False

    # Update stock profiles in stock_vectors for each affected stock
    now_iso = datetime.now(timezone.utc).isoformat()
    for imp in impacts:
        sym = str(imp.get("symbol", "")).upper().strip()
        if not sym:
            continue
        await _update_stock_profile(
            symbol=sym,
            name=str(imp.get("name", sym)),
            sector=str(imp.get("sector", sector)),
            article_id=article_id,
            headline=headline,
            now_iso=now_iso,
        )

    logger.info(
        "Vector sync complete for article %s → stocks: %s",
        article_id,
        stock_symbols,
    )
    return True


async def _update_stock_profile(
    symbol: str,
    name: str,
    sector: str,
    article_id: str,
    headline: str,
    now_iso: str,
) -> None:
    """Rebuild the stock profile embedding incorporating the new article."""
    try:
        # Retrieve existing articles for this stock to build cumulative context
        existing_news = await search_news_for_stock(symbol, k=15)
        related_ids = [n["article_id"] for n in existing_news if "article_id" in n]
        if article_id not in related_ids:
            related_ids.insert(0, article_id)

        # Build cumulative summary text for stock embedding
        headlines = [headline] + [n.get("headline", "") for n in existing_news[:9]]
        keywords = _extract_keywords(headlines)
        impact_summary = f"Stock {symbol} ({name}) is affected by news related to: {', '.join(keywords[:10])}."

        embed_input = f"{symbol} {name} {sector}. " + " ".join(headlines[:5])
        vector = await embed_text(embed_input)
        if vector is None:
            return

        await upsert_stock_profile(
            symbol=symbol,
            name=name,
            sector=sector,
            vector=vector,
            training_keywords=keywords,
            related_article_ids=related_ids[:50],  # Keep latest 50
            impact_summary=impact_summary,
            last_trained_at=now_iso,
        )
    except Exception as exc:
        logger.error("_update_stock_profile(%s) failed: %s", symbol, exc)


def _majority(items: list[str]) -> str:
    """Return the most frequent item in a list."""
    if not items:
        return "neutral"
    return max(set(items), key=items.count)


def _extract_keywords(headlines: list[str]) -> list[str]:
    """Extract meaningful words from headlines as training keywords."""
    stop = {
        "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
        "and", "or", "but", "in", "on", "at", "to", "for", "of", "with",
        "this", "that", "it", "its", "as", "by", "from", "have", "has", "had",
        "will", "would", "could", "should", "may", "might", "up", "down",
        "after", "before", "over", "under", "into", "out", "than", "more",
        "per", "amid", "says", "said", "report", "reports",
    }
    words: dict[str, int] = {}
    for h in headlines:
        for w in h.lower().split():
            clean = w.strip(".,;:!?\"'()-")
            if len(clean) > 3 and clean not in stop:
                words[clean] = words.get(clean, 0) + 1
    return [w for w, _ in sorted(words.items(), key=lambda x: -x[1])]
