"""
AWS Bedrock Embedder for MarketPulse.

Uses Amazon Titan Text Embeddings V2 (amazon.titan-embed-text-v2:0)
to produce 1536-dimensional vectors from article text.

All embedding work is 100% AWS — no GCP or Azure.
"""

from __future__ import annotations

import asyncio
import json
import logging
from functools import lru_cache
from typing import Optional

import boto3
from botocore.exceptions import BotoCoreError, ClientError

from app.config import get_settings

logger = logging.getLogger(__name__)

MODEL_ID = "amazon.titan-embed-text-v2:0"
EMBEDDING_DIM = 1536


@lru_cache(maxsize=1)
def _get_bedrock_client():
    """Lazy singleton Bedrock runtime client."""
    settings = get_settings()
    if not settings.AWS_ACCESS_KEY_ID or not settings.AWS_SECRET_ACCESS_KEY:
        logger.warning("AWS credentials not configured – embeddings will be disabled")
        return None
    return boto3.client(
        "bedrock-runtime",
        region_name=settings.AWS_REGION,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    )


async def embed_text(text: str) -> Optional[list[float]]:
    """
    Generate a 1536-dim embedding for the given text using AWS Bedrock Titan.

    Returns None if AWS is not configured or if the call fails.
    Truncates input to 8000 characters (Titan limit).
    """
    client = _get_bedrock_client()
    if client is None:
        return None

    # Titan V2 has an 8192 token limit; truncate conservatively
    truncated = text[:8000].strip()
    if not truncated:
        return None

    body = json.dumps({"inputText": truncated})

    loop = asyncio.get_event_loop()
    try:
        response = await loop.run_in_executor(
            None,
            lambda: client.invoke_model(
                modelId=MODEL_ID,
                body=body,
                contentType="application/json",
                accept="application/json",
            ),
        )
        result = json.loads(response["body"].read())
        embedding = result.get("embedding")
        if embedding and len(embedding) == EMBEDDING_DIM:
            return embedding
        logger.error("Unexpected embedding shape from Bedrock: %s", len(embedding) if embedding else None)
        return None
    except (BotoCoreError, ClientError) as exc:
        logger.error("Bedrock embed_text failed: %s", exc)
        return None
    except Exception as exc:
        logger.error("Unexpected error in embed_text: %s", exc)
        return None


async def is_available() -> bool:
    """Quick health check – tries to embed a short string."""
    result = await embed_text("health check")
    return result is not None
