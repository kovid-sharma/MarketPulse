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



_COMPANY_NAMES: dict[str, str] = {
    "HDFCBANK": "HDFC Bank Ltd",
    "ICICIBANK": "ICICI Bank Ltd",
    "SBIN": "State Bank of India",
    "KOTAKBANK": "Kotak Mahindra Bank Ltd",
    "AXISBANK": "Axis Bank Ltd",
    "HINDUNILVR": "Hindustan Unilever Ltd",
    "ITC": "ITC Ltd",
    "NESTLEIND": "Nestle India Ltd",
    "NIFTY50": "Nifty 50 Index",
    "TCS": "Tata Consultancy Services Ltd",
    "INFY": "Infosys Ltd",
    "WIPRO": "Wipro Ltd",
    "HCLTECH": "HCL Technologies Ltd",
    "RELIANCE": "Reliance Industries Ltd",
    "ONGC": "Oil & Natural Gas Corporation Ltd",
    "IOC": "Indian Oil Corporation Ltd",
    "INDIGO": "InterGlobe Aviation Ltd (IndiGo)",
    "SPICEJET": "SpiceJet Ltd",
    "SUNPHARMA": "Sun Pharmaceutical Industries Ltd",
    "DRREDDY": "Dr. Reddy's Laboratories Ltd",
    "CIPLA": "Cipla Ltd",
    "TATAMOTORS": "Tata Motors Ltd",
    "M&M": "Mahindra & Mahindra Ltd",
    "MARUTI": "Maruti Suzuki India Ltd",
    "DLF": "DLF Ltd",
    "GODREJPROP": "Godrej Properties Ltd",
    "MARICO": "Marico Ltd",
    "PNB": "Punjab National Bank",
    "BANKBARODA": "Bank of Baroda"
}


def map_impact(article_text: str) -> list[dict[str, Any]]:
    """
    Match article text against the static IMPACT_MAP.

    Returns a list of matched impact dicts conforming to the StockImpact schema.
    """
    text_lower = article_text.lower()
    matched: list[dict[str, Any]] = []
    seen_symbols: set[str] = set()

    for keyword, impact in IMPACT_MAP.items():
        pattern = re.compile(r"\b" + re.escape(keyword) + r"\b")
        if pattern.search(text_lower):
            sector = impact["sector"]
            direction = impact["direction"]
            stocks = impact.get("stocks", [])
            for stock_symbol in stocks:
                symbol_upper = stock_symbol.upper().strip()
                if symbol_upper not in seen_symbols:
                    seen_symbols.add(symbol_upper)
                    name = _COMPANY_NAMES.get(symbol_upper, symbol_upper)
                    matched.append(
                        {
                            "symbol": symbol_upper,
                            "name": name,
                            "sector": sector,
                            "direction": direction,
                            "effect": "medium",  # default fallback impact
                            "reason": f"Potentially affected by keyword '{keyword}' in {sector} sector.",
                        }
                    )

    logger.debug("Impact mapper found %d stock matches", len(matched))
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
