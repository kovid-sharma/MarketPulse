"""
AI enrichment via Gemini.

Produces: summary, context, impact_explanation, key_takeaway, sentiment.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from app.models.article import NormalizedArticle
from app.pipeline.gemini_client import generate_json

logger = logging.getLogger(__name__)

_ENRICHMENT_PROMPT = """
You are a financial news analyst for Indian markets. Analyse the article below and return
enriched metadata. Respond ONLY with valid JSON, no markdown fences.

Article headline: {headline}
Article content: {content}

Return exactly:
{{
  "summary": "2-3 sentence plain-English summary of the article",
  "context": "Why this news matters right now – 1-2 sentences",
  "impact_explanation": "Explain the likely market or economic impact",
  "key_takeaway": "Single most important point an investor should know",
  "sentiment": "bullish" | "bearish" | "neutral"
}}

Definitions:
- bullish: news is likely to drive prices up
- bearish: news is likely to drive prices down
- neutral: no clear directional impact
"""


@dataclass
class EnrichmentResult:
    summary: str
    context: str
    impact_explanation: str
    key_takeaway: str
    sentiment: str  # bullish | bearish | neutral


async def enrich_article(article: NormalizedArticle) -> EnrichmentResult:
    """Call Gemini to enrich an article with summary, sentiment, etc."""
    try:
        prompt = _ENRICHMENT_PROMPT.format(
            headline=article.headline,
            content=(article.content or "")[:1200],
        )
        result = await generate_json(prompt)

        sentiment = result.get("sentiment", "neutral")
        if sentiment not in ("bullish", "bearish", "neutral"):
            sentiment = "neutral"

        return EnrichmentResult(
            summary=result.get("summary", ""),
            context=result.get("context", ""),
            impact_explanation=result.get("impact_explanation", ""),
            key_takeaway=result.get("key_takeaway", ""),
            sentiment=sentiment,
        )
    except Exception as exc:
        logger.error("Enrichment failed: %s", exc)
        return EnrichmentResult(
            summary="",
            context="",
            impact_explanation="",
            key_takeaway="",
            sentiment="neutral",
        )
