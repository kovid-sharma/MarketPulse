"""
AI enrichment via Gemini.

Produces: summary, context, impact_explanation, key_takeaway, sentiment,
          markets_affected, trade_logic, stock_impacts (with per-stock effect level).
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any

from app.models.article import NormalizedArticle
from app.pipeline.gemini_client import generate_json

logger = logging.getLogger(__name__)

_ENRICHMENT_PROMPT = """
You are a financial news analyst for Indian markets. Analyse the article below and return
enriched metadata as JSON. Respond ONLY with valid JSON, no markdown fences.

{rag_context}
Article headline: {headline}
Article content: {content}

Return exactly this JSON structure:
{{
  "summary": "2-3 sentence plain-English summary of the article",
  "context": "Why this news matters right now - 1-2 sentences",
  "impact_explanation": "Explain the likely market or economic impact",
  "key_takeaway": "Single most important point an investor should know",
  "sentiment": "bullish" | "bearish" | "neutral",
  "markets_affected": ["list of market categories or sectors impacted, e.g. Banking, Oil & Gas, IT, FMCG, Auto, Pharma, Realty, Broad Market"],
  "trade_logic": "A clear explanation of the reasoning behind how this news affects the listed stocks - the causal chain from news event to stock price movement, including relevant macro or micro factors",
  "stock_impacts": [
    {{
      "symbol": "NSE_TICKER_SYMBOL",
      "name": "Company Name",
      "sector": "sector name",
      "direction": "positive" | "negative" | "neutral",
      "effect": "high" | "medium" | "low",
      "reason": "One sentence explaining why this specific stock is affected"
    }}
  ]
}}

Guidelines:
- Use the HISTORICAL CONTEXT above (if provided) to calibrate your stock impact predictions.
  Prefer patterns from admin-verified examples over AI-predicted ones.
- sentiment: bullish = prices likely up, bearish = prices likely down, neutral = no clear direction
- markets_affected: list only the major market segments impacted (2-5 items max)
- trade_logic: explain the causal chain in 2-4 sentences, suitable for a retail investor
- stock_impacts: list 3-8 specific NSE-listed stocks most directly impacted
  - effect HIGH: stock is directly, significantly affected (e.g. company is subject of news)
  - effect MEDIUM: stock is moderately affected (e.g. sector peer, supply chain link)
  - effect LOW: stock has marginal or indirect exposure
  - Use NSE ticker symbols (e.g. RELIANCE, HDFCBANK, TCS, INFY, SBIN, TATAMOTORS)
- If the article is not clearly related to specific stocks, return an empty stock_impacts array
"""


@dataclass
class EnrichmentResult:
    summary: str
    context: str
    impact_explanation: str
    key_takeaway: str
    sentiment: str  # bullish | bearish | neutral
    markets_affected: list[str] = field(default_factory=list)
    trade_logic: str = ""
    stock_impacts: list[dict[str, Any]] = field(default_factory=list)


async def enrich_article(article: NormalizedArticle) -> EnrichmentResult:
    """Call Gemini to enrich an article with summary, sentiment, and per-stock impact data.
    
    Injects RAG context from AWS OpenSearch vector store if available,
    using similar past articles (especially admin-verified ones) to improve accuracy.
    """
    try:
        # Retrieve RAG context from AWS OpenSearch (non-blocking, fails gracefully)
        from app.vector.rag_context import build_rag_context
        article_text = f"{article.headline}. {(article.content or '')[:2000]}"
        rag_context = await build_rag_context(article_text)
        if rag_context:
            rag_context = rag_context + "\n\n"
            logger.info("RAG context injected for article: %s", article.headline[:60])

        prompt = _ENRICHMENT_PROMPT.format(
            rag_context=rag_context,
            headline=article.headline,
            content=(article.content or "")[:2000],
        )
        result = await generate_json(prompt)

        sentiment = result.get("sentiment", "neutral")
        if sentiment not in ("bullish", "bearish", "neutral"):
            sentiment = "neutral"

        # Validate and normalise stock_impacts
        raw_impacts = result.get("stock_impacts", [])
        stock_impacts: list[dict[str, Any]] = []
        for item in raw_impacts:
            if not isinstance(item, dict):
                continue
            effect = item.get("effect", "low")
            if effect not in ("high", "medium", "low"):
                effect = "low"
            direction = item.get("direction", "neutral")
            if direction not in ("positive", "negative", "neutral"):
                direction = "neutral"
            stock_impacts.append({
                "symbol": str(item.get("symbol", "")).upper().strip(),
                "name": str(item.get("name", item.get("symbol", ""))).strip(),
                "sector": str(item.get("sector", "")).strip(),
                "direction": direction,
                "effect": effect,
                "reason": str(item.get("reason", "")).strip(),
            })

        markets_affected = result.get("markets_affected", [])
        if not isinstance(markets_affected, list):
            markets_affected = []

        return EnrichmentResult(
            summary=result.get("summary", ""),
            context=result.get("context", ""),
            impact_explanation=result.get("impact_explanation", ""),
            key_takeaway=result.get("key_takeaway", ""),
            sentiment=sentiment,
            markets_affected=[str(m) for m in markets_affected],
            trade_logic=str(result.get("trade_logic", "")),
            stock_impacts=stock_impacts,
        )
    except Exception as exc:
        logger.error("Enrichment failed: %s", exc)
        return EnrichmentResult(
            summary="",
            context="",
            impact_explanation="",
            key_takeaway="",
            sentiment="neutral",
            markets_affected=[],
            trade_logic="",
            stock_impacts=[],
        )
