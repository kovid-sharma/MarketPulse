"""
Keyword/rule-based stock impact mapper.

Maps article text to sectors, stocks, and directional impact.
This is intentionally a pluggable function – the interface will remain stable
when this is later replaced by a Neo4j-backed service.
"""

from __future__ import annotations

import logging
import re
from typing import Any

logger = logging.getLogger(__name__)

# ── Static mapping: keyword → impact entry ────────────────────────────────────
# Each entry: {"sector": str, "stocks": [str], "direction": "positive"|"negative"|"neutral"}

IMPACT_MAP: dict[str, dict[str, Any]] = {
    # Macro / RBI
    "rbi rate hike": {
        "sector": "banking",
        "stocks": ["HDFCBANK", "ICICIBANK", "SBIN"],
        "direction": "negative",
    },
    "rbi rate cut": {
        "sector": "banking",
        "stocks": ["HDFCBANK", "ICICIBANK", "SBIN"],
        "direction": "positive",
    },
    "repo rate": {
        "sector": "banking",
        "stocks": ["HDFCBANK", "ICICIBANK", "KOTAKBANK"],
        "direction": "neutral",
    },
    "inflation": {
        "sector": "fmcg",
        "stocks": ["HINDUNILVR", "ITC", "NESTLEIND"],
        "direction": "negative",
    },
    "gdp growth": {
        "sector": "broad market",
        "stocks": ["NIFTY50"],
        "direction": "positive",
    },
    "rupee depreciation": {
        "sector": "it",
        "stocks": ["TCS", "INFY", "WIPRO", "HCLTECH"],
        "direction": "positive",
    },
    "rupee appreciation": {
        "sector": "it",
        "stocks": ["TCS", "INFY", "WIPRO"],
        "direction": "negative",
    },
    "crude oil": {
        "sector": "oil & gas",
        "stocks": ["RELIANCE", "ONGC", "IOC"],
        "direction": "neutral",
    },
    "crude oil rise": {
        "sector": "oil & gas",
        "stocks": ["RELIANCE", "ONGC"],
        "direction": "positive",
    },
    "crude oil fall": {
        "sector": "aviation",
        "stocks": ["INDIGO", "SPICEJET"],
        "direction": "positive",
    },
    # Sectors
    "pharma": {
        "sector": "pharma",
        "stocks": ["SUNPHARMA", "DRREDDY", "CIPLA"],
        "direction": "neutral",
    },
    "it sector": {
        "sector": "it",
        "stocks": ["TCS", "INFY", "WIPRO", "HCLTECH"],
        "direction": "neutral",
    },
    "auto sales": {
        "sector": "auto",
        "stocks": ["TATAMOTORS", "M&M", "MARUTI"],
        "direction": "positive",
    },
    "ev": {
        "sector": "auto/ev",
        "stocks": ["TATAMOTORS", "M&M"],
        "direction": "positive",
    },
    "real estate": {
        "sector": "realty",
        "stocks": ["DLF", "GODREJPROP"],
        "direction": "neutral",
    },
    "fmcg": {
        "sector": "fmcg",
        "stocks": ["HINDUNILVR", "ITC", "MARICO"],
        "direction": "neutral",
    },
    "banking": {
        "sector": "banking",
        "stocks": ["HDFCBANK", "ICICIBANK", "SBIN", "AXISBANK"],
        "direction": "neutral",
    },
    "npa": {
        "sector": "banking",
        "stocks": ["SBIN", "PNB", "BANKBARODA"],
        "direction": "negative",
    },
    "ipo": {"sector": "broad market", "stocks": [], "direction": "positive"},
    # Global
    "us fed rate": {"sector": "it", "stocks": ["TCS", "INFY"], "direction": "negative"},
    "global recession": {
        "sector": "broad market",
        "stocks": ["NIFTY50"],
        "direction": "negative",
    },
    "fii buying": {
        "sector": "broad market",
        "stocks": ["NIFTY50"],
        "direction": "positive",
    },
    "fii selling": {
        "sector": "broad market",
        "stocks": ["NIFTY50"],
        "direction": "negative",
    },
}


def map_impact(article_text: str) -> list[dict[str, Any]]:
    """
    Match article text against the static IMPACT_MAP.

    Returns a list of matched impact dicts.
    Interface is stable – can be swapped for Neo4j lookup without touching callers.
    """
    text_lower = article_text.lower()
    matched: list[dict[str, Any]] = []
    seen_sectors: set[str] = set()

    for keyword, impact in IMPACT_MAP.items():
        pattern = re.compile(r"\b" + re.escape(keyword) + r"\b")
        if pattern.search(text_lower):
            sector = impact["sector"]
            if sector not in seen_sectors:
                seen_sectors.add(sector)
                matched.append(
                    {
                        "keyword": keyword,
                        "sector": sector,
                        "stocks": impact["stocks"],
                        "direction": impact["direction"],
                    }
                )

    logger.debug("Impact mapper found %d matches", len(matched))
    return matched


# ── Runtime config helpers ─────────────────────────────────────────────────────────────


def get_impact_map() -> dict[str, dict[str, Any]]:
    """Return a copy of the current impact mapping (for admin config API)."""
    return dict(IMPACT_MAP)


def set_impact_map(new_map: dict[str, dict[str, Any]]) -> None:
    """
    Replace the in-memory impact mapping at runtime.
    Called by the admin config API – changes are live immediately.
    """
    global IMPACT_MAP
    IMPACT_MAP = new_map
    logger.info("Impact map updated with %d entries", len(IMPACT_MAP))
