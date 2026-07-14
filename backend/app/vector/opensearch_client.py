"""
Amazon OpenSearch Serverless client for MarketPulse vector store.

Two k-NN indices:
  - news_vectors  : article → stocks mapping (news affects stocks)
  - stock_vectors : stock  → news mapping  (vice-versa: stock affected by news)

All AWS, no other cloud dependency.
"""

from __future__ import annotations

import logging
import uuid
from typing import Any, Optional

from app.config import get_settings

logger = logging.getLogger(__name__)

# Index names
NEWS_INDEX = "news_vectors"
STOCK_INDEX = "stock_vectors"
EMBEDDING_DIM = 1536


def _get_client():
    """Lazy OpenSearch client using AWS request signing (AOSS)."""
    settings = get_settings()
    if not settings.OPENSEARCH_ENDPOINT or not settings.AWS_ACCESS_KEY_ID:
        return None
    try:
        from opensearchpy import OpenSearch, RequestsHttpConnection, AWSV4SignerAuth
        import boto3

        credentials = boto3.Session(
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=settings.AWS_REGION,
        ).get_credentials()

        auth = AWSV4SignerAuth(credentials, settings.AWS_REGION, "aoss")

        endpoint = settings.OPENSEARCH_ENDPOINT.replace("https://", "").replace("http://", "")
        client = OpenSearch(
            hosts=[{"host": endpoint, "port": 443}],
            http_auth=auth,
            use_ssl=True,
            verify_certs=True,
            connection_class=RequestsHttpConnection,
            timeout=30,
        )
        return client
    except ImportError:
        logger.error("opensearch-py not installed. Run: pip install opensearch-py")
        return None
    except Exception as exc:
        logger.error("OpenSearch client init failed: %s", exc)
        return None


_INDEX_BODY = {
    "settings": {
        "index": {
            "knn": True,
            "knn.algo_param.ef_search": 100,
        }
    },
    "mappings": {
        "properties": {
            "vector": {
                "type": "knn_vector",
                "dimension": EMBEDDING_DIM,
                "method": {
                    "name": "hnsw",
                    "space_type": "cosinesimil",
                    "engine": "nmslib",
                    "parameters": {"ef_construction": 128, "m": 16},
                },
            },
            "article_id": {"type": "keyword"},
            "headline": {"type": "text"},
            "content_snippet": {"type": "text"},
            "stock_symbols": {"type": "keyword"},
            "stock_names": {"type": "keyword"},
            "sector": {"type": "keyword"},
            "direction": {"type": "keyword"},
            "sentiment": {"type": "keyword"},
            "published_at": {"type": "date"},
            "admin_verified": {"type": "boolean"},
        }
    },
}

_STOCK_INDEX_BODY = {
    "settings": {"index": {"knn": True, "knn.algo_param.ef_search": 100}},
    "mappings": {
        "properties": {
            "vector": {
                "type": "knn_vector",
                "dimension": EMBEDDING_DIM,
                "method": {
                    "name": "hnsw",
                    "space_type": "cosinesimil",
                    "engine": "nmslib",
                    "parameters": {"ef_construction": 128, "m": 16},
                },
            },
            "symbol": {"type": "keyword"},
            "name": {"type": "keyword"},
            "sector": {"type": "keyword"},
            "training_keywords": {"type": "keyword"},
            "related_article_ids": {"type": "keyword"},
            "impact_summary": {"type": "text"},
            "last_trained_at": {"type": "date"},
        }
    },
}


def setup_indices() -> bool:
    """Create OpenSearch indices if they don't exist. Returns True on success."""
    client = _get_client()
    if client is None:
        logger.warning("OpenSearch not configured – skipping index setup")
        return False
    try:
        for idx, body in [(NEWS_INDEX, _INDEX_BODY), (STOCK_INDEX, _STOCK_INDEX_BODY)]:
            if not client.indices.exists(idx):
                client.indices.create(idx, body=body)
                logger.info("Created OpenSearch index: %s", idx)
            else:
                logger.info("OpenSearch index already exists: %s", idx)
        return True
    except Exception as exc:
        logger.error("setup_indices failed: %s", exc)
        return False


async def index_article(
    article_id: str,
    headline: str,
    content: str,
    vector: list[float],
    stock_symbols: list[str],
    stock_names: list[str],
    sector: str,
    direction: str,
    sentiment: str,
    published_at: Optional[str],
    admin_verified: bool = False,
) -> Optional[str]:
    """
    Index an article into news_vectors.
    Returns the OpenSearch document ID on success, None on failure.
    """
    import asyncio

    client = _get_client()
    if client is None:
        return None

    doc = {
        "vector": vector,
        "article_id": article_id,
        "headline": headline,
        "content_snippet": content[:500],
        "stock_symbols": stock_symbols,
        "stock_names": stock_names,
        "sector": sector,
        "direction": direction,
        "sentiment": sentiment,
        "published_at": published_at,
        "admin_verified": admin_verified,
    }

    loop = asyncio.get_event_loop()
    try:
        resp = await loop.run_in_executor(
            None,
            lambda: client.index(index=NEWS_INDEX, id=article_id, body=doc),
        )
        logger.info("Indexed article %s → OpenSearch (result=%s)", article_id, resp.get("result"))
        return article_id
    except Exception as exc:
        logger.error("index_article failed for %s: %s", article_id, exc)
        return None


async def update_article_stocks(
    article_id: str,
    stock_symbols: list[str],
    stock_names: list[str],
    sector: str,
    direction: str,
    admin_verified: bool = True,
) -> bool:
    """Admin override: update stock associations for a news article."""
    import asyncio

    client = _get_client()
    if client is None:
        return False

    update_body = {
        "doc": {
            "stock_symbols": stock_symbols,
            "stock_names": stock_names,
            "sector": sector,
            "direction": direction,
            "admin_verified": admin_verified,
        }
    }
    loop = asyncio.get_event_loop()
    try:
        await loop.run_in_executor(
            None,
            lambda: client.update(index=NEWS_INDEX, id=article_id, body=update_body),
        )
        logger.info("Updated vector stocks for article %s (admin_verified=%s)", article_id, admin_verified)
        return True
    except Exception as exc:
        logger.error("update_article_stocks failed: %s", exc)
        return False


async def search_similar_news(
    query_vector: list[float], k: int = 5, min_score: float = 0.6
) -> list[dict[str, Any]]:
    """
    Find k most similar articles to the query vector (for RAG context injection).
    Returns admin_verified articles first.
    """
    import asyncio

    client = _get_client()
    if client is None:
        return []

    query = {
        "size": k * 2,
        "query": {
            "knn": {
                "vector": {"vector": query_vector, "k": k * 2}
            }
        },
        "_source": ["article_id", "headline", "stock_symbols", "sector", "direction", "sentiment", "admin_verified", "content_snippet"],
    }

    loop = asyncio.get_event_loop()
    try:
        resp = await loop.run_in_executor(None, lambda: client.search(index=NEWS_INDEX, body=query))
        hits = resp.get("hits", {}).get("hits", [])
        # Prefer admin-verified results
        hits.sort(key=lambda h: (not h["_source"].get("admin_verified", False), -h.get("_score", 0)))
        return [h["_source"] for h in hits[:k] if h.get("_score", 0) >= min_score]
    except Exception as exc:
        logger.error("search_similar_news failed: %s", exc)
        return []


async def search_news_for_stock(
    symbol: str, k: int = 20, admin_verified_only: bool = False
) -> list[dict[str, Any]]:
    """
    Vice-versa: find top news articles that affected a given stock symbol.
    """
    import asyncio

    client = _get_client()
    if client is None:
        return []

    must_clauses: list[dict] = [{"term": {"stock_symbols": symbol.upper()}}]
    if admin_verified_only:
        must_clauses.append({"term": {"admin_verified": True}})

    query = {
        "size": k,
        "query": {"bool": {"must": must_clauses}},
        "sort": [{"published_at": {"order": "desc"}}],
        "_source": ["article_id", "headline", "sector", "direction", "sentiment", "published_at", "admin_verified", "content_snippet"],
    }

    loop = asyncio.get_event_loop()
    try:
        resp = await loop.run_in_executor(None, lambda: client.search(index=NEWS_INDEX, body=query))
        return [h["_source"] for h in resp.get("hits", {}).get("hits", [])]
    except Exception as exc:
        logger.error("search_news_for_stock(%s) failed: %s", symbol, exc)
        return []


async def upsert_stock_profile(
    symbol: str,
    name: str,
    sector: str,
    vector: list[float],
    training_keywords: list[str],
    related_article_ids: list[str],
    impact_summary: str,
    last_trained_at: str,
) -> bool:
    """Create or update a stock profile document in stock_vectors index."""
    import asyncio

    client = _get_client()
    if client is None:
        return False

    doc = {
        "vector": vector,
        "symbol": symbol.upper(),
        "name": name,
        "sector": sector,
        "training_keywords": training_keywords,
        "related_article_ids": related_article_ids,
        "impact_summary": impact_summary,
        "last_trained_at": last_trained_at,
    }

    loop = asyncio.get_event_loop()
    try:
        await loop.run_in_executor(
            None,
            lambda: client.index(index=STOCK_INDEX, id=symbol.upper(), body=doc),
        )
        logger.info("Upserted stock profile: %s", symbol)
        return True
    except Exception as exc:
        logger.error("upsert_stock_profile(%s) failed: %s", symbol, exc)
        return False


async def get_index_stats() -> dict[str, Any]:
    """Return document counts for both indices."""
    import asyncio

    client = _get_client()
    if client is None:
        return {"available": False, "news_count": 0, "stock_count": 0}

    loop = asyncio.get_event_loop()
    try:
        def _stats():
            news_count = client.count(index=NEWS_INDEX).get("count", 0) if client.indices.exists(NEWS_INDEX) else 0
            stock_count = client.count(index=STOCK_INDEX).get("count", 0) if client.indices.exists(STOCK_INDEX) else 0
            return news_count, stock_count

        news_count, stock_count = await loop.run_in_executor(None, _stats)
        return {"available": True, "news_count": news_count, "stock_count": stock_count}
    except Exception as exc:
        logger.error("get_index_stats failed: %s", exc)
        return {"available": False, "news_count": 0, "stock_count": 0, "error": str(exc)}
