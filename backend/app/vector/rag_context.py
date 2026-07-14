"""
RAG context builder for MarketPulse.

Retrieves similar past articles from the AWS OpenSearch vector store
and formats them as context to inject into the Gemini enrichment prompt.

This makes Gemini aware of historical stock-news cause-effect patterns
that have been admin-curated, significantly improving prediction quality.
"""

from __future__ import annotations

import logging

from app.vector.bedrock_embedder import embed_text
from app.vector.opensearch_client import search_similar_news

logger = logging.getLogger(__name__)


async def build_rag_context(article_text: str, max_examples: int = 4) -> str:
    """
    Embed the article text, search for similar past articles with known
    stock impacts, and return a formatted context block.

    Returns an empty string if the vector store is unavailable or empty.
    """
    try:
        vector = await embed_text(article_text)
        if vector is None:
            return ""

        similar = await search_similar_news(vector, k=max_examples)
        if not similar:
            return ""

        lines = [
            "HISTORICAL CONTEXT (similar news and their verified stock impacts):",
            "Use these examples to inform your stock impact predictions.\n",
        ]

        for i, item in enumerate(similar, 1):
            headline = item.get("headline", "")
            symbols = item.get("stock_symbols", [])
            direction = item.get("direction", "neutral")
            sector = item.get("sector", "")
            sentiment = item.get("sentiment", "neutral")
            verified = "✓ Admin verified" if item.get("admin_verified") else "AI predicted"
            snippet = item.get("content_snippet", "")

            symbols_str = ", ".join(symbols) if symbols else "N/A"
            lines.append(
                f"Example {i} [{verified}]:\n"
                f"  Headline: {headline}\n"
                f"  Stocks affected: {symbols_str} | Sector: {sector}\n"
                f"  Direction: {direction} | Market Sentiment: {sentiment}\n"
                f"  Context: {snippet[:200]}\n"
            )

        return "\n".join(lines)
    except Exception as exc:
        logger.warning("build_rag_context failed (non-fatal): %s", exc)
        return ""
