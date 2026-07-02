"""
Article classifier via Gemini.

Returns credibility (confirmed | opinion) and geography (india | global)
with a confidence score. Articles below threshold are flagged for review.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from app.config import get_settings
from app.models.article import NormalizedArticle
from app.pipeline.gemini_client import generate_json

logger = logging.getLogger(__name__)
settings = get_settings()

_CLASSIFY_PROMPT = """
You are a financial news classifier. Analyse the article below and return a JSON object.
Respond ONLY with valid JSON, no markdown fences.

Article headline: {headline}
Article content: {content}

Return exactly:
{{
  "credibility": "confirmed" or "opinion",
  "geography": "india" or "global",
  "confidence": <float between 0.0 and 1.0>
}}

Guidelines:
- credibility "confirmed": factual reporting with verifiable data.
- credibility "opinion": editorial, analysis, or speculative content.
- geography "india": primarily about Indian markets, companies, or economy.
- geography "global": primarily about international markets or has global scope.
- confidence: your certainty in these classifications.
"""


@dataclass
class ClassificationResult:
    credibility: str
    geography: str
    confidence: float
    needs_review: bool


async def classify_article(article: NormalizedArticle) -> ClassificationResult:
    """Classify article credibility and geography via Gemini."""
    try:
        prompt = _CLASSIFY_PROMPT.format(
            headline=article.headline,
            content=(article.content or "")[:800],
        )
        result = await generate_json(prompt)

        credibility = result.get("credibility", "confirmed")
        geography = result.get("geography", "global")
        confidence = float(result.get("confidence", 0.5))

        # Normalise values
        if credibility not in ("confirmed", "opinion"):
            credibility = "confirmed"
        if geography not in ("india", "global"):
            geography = "global"

        needs_review = confidence < settings.FINANCE_FILTER_CONFIDENCE_THRESHOLD

        return ClassificationResult(
            credibility=credibility,
            geography=geography,
            confidence=confidence,
            needs_review=needs_review,
        )
    except Exception as exc:
        logger.error("Classifier failed: %s", exc)
        return ClassificationResult(
            credibility="confirmed",
            geography="global",
            confidence=0.0,
            needs_review=True,
        )
