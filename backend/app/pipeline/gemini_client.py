"""
Centralised Gemini API helper.

All pipeline steps (filter, classifier, enrichment) call generate_json() from here.
"""

from __future__ import annotations

import asyncio
import json
import logging
import re

import google.generativeai as genai

from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

# Configure once at import
genai.configure(api_key=settings.GEMINI_API_KEY)
_model = genai.GenerativeModel(settings.GEMINI_MODEL)


def _extract_json(text: str) -> dict:
    """
    Extract first JSON object from a Gemini response that may contain
    markdown fences or trailing text.
    """
    # Strip markdown fences
    text = re.sub(r"```(?:json)?", "", text).strip()
    # Find the first {...} block
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if match:
        return json.loads(match.group())
    raise ValueError(f"No JSON object found in response: {text[:200]}")


async def generate_json(prompt: str) -> dict:
    """
    Send a prompt to Gemini and return the parsed JSON response.
    Retries up to GEMINI_MAX_RETRIES times on transient failures.
    """
    last_exc: Exception | None = None

    for attempt in range(1, settings.GEMINI_MAX_RETRIES + 1):
        try:
            response = await asyncio.to_thread(
                _model.generate_content,
                prompt,
                generation_config=genai.GenerationConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                ),
            )
            text = response.text
            return _extract_json(text)
        except json.JSONDecodeError as exc:
            logger.warning("Gemini JSON parse error (attempt %d): %s", attempt, exc)
            last_exc = exc
        except Exception as exc:
            logger.warning("Gemini call failed (attempt %d): %s", attempt, exc)
            last_exc = exc
            await asyncio.sleep(2**attempt)  # exponential back-off

    raise RuntimeError(
        f"Gemini failed after {settings.GEMINI_MAX_RETRIES} attempts"
    ) from last_exc
