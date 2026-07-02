"""
Finance relevance filter.

Step 1 – fast keyword/blocklist check.
Step 2 – Gemini fallback for ambiguous articles.
"""

from __future__ import annotations

import logging

from app.models.article import NormalizedArticle
from app.pipeline.gemini_client import generate_json

logger = logging.getLogger(__name__)

# ── Keyword lists ─────────────────────────────────────────────────────────────

FINANCE_KEYWORDS = {
    "stock",
    "share",
    "equity",
    "nifty",
    "sensex",
    "bse",
    "nse",
    "market",
    "ipo",
    "fund",
    "mutual fund",
    "rbi",
    "sebi",
    "economy",
    "gdp",
    "inflation",
    "interest rate",
    "bond",
    "debt",
    "rupee",
    "forex",
    "commodity",
    "gold",
    "silver",
    "crude",
    "banking",
    "insurance",
    "profit",
    "revenue",
    "earnings",
    "quarterly",
    "budget",
    "fiscal",
    "trade",
    "export",
    "import",
    "startup",
    "venture",
    "investment",
    "portfolio",
    "dividend",
    "capital",
    "merger",
    "acquisition",
    "ipo",
    "listing",
    "benchmark",
}

BLOCKLIST_KEYWORDS = {
    "cricket",
    "bollywood",
    "celebrity",
    "movie",
    "film",
    "recipe",
    "sports",
    "fashion",
    "entertainment",
    "astrology",
    "horoscope",
    "weather",
}


def _text(article: NormalizedArticle) -> str:
    return f"{article.headline} {article.content or ''}".lower()


def _fast_check(text: str) -> str:
    """Returns 'relevant', 'irrelevant', or 'ambiguous'."""
    if any(kw in text for kw in BLOCKLIST_KEYWORDS):
        return "irrelevant"
    if any(kw in text for kw in FINANCE_KEYWORDS):
        return "relevant"
    return "ambiguous"


_FILTER_PROMPT = """
You are a financial news analyst. Decide if the following article is financially relevant.
Respond ONLY with valid JSON, no markdown.

Article headline: {headline}
Article content: {content}

Return:
{{
  "is_relevant": true | false,
  "reason": "brief explanation"
}}
"""


async def is_financially_relevant(article: NormalizedArticle) -> tuple[bool, str]:
    """
    Returns (is_relevant, reason).
    Uses fast keyword check first; calls Gemini only for ambiguous cases.
    """
    text = _text(article)
    verdict = _fast_check(text)

    if verdict == "relevant":
        return True, "Matched financial keywords"
    if verdict == "irrelevant":
        return False, "Matched blocklist keywords"

    # Ambiguous – ask Gemini
    try:
        prompt = _FILTER_PROMPT.format(
            headline=article.headline,
            content=(article.content or "")[:500],
        )
        result = await generate_json(prompt)
        is_rel = bool(result.get("is_relevant", False))
        reason = result.get("reason", "Gemini decision")
        return is_rel, reason
    except Exception as exc:
        logger.warning(
            "Finance filter Gemini call failed: %s – marking relevant by default", exc
        )
        return True, "Gemini unavailable – defaulting to relevant"
