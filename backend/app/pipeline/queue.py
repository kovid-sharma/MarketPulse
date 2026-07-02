"""
Async queue wrapper.

Currently backed by asyncio.Queue.
The interface is intentionally generic so it can be swapped for
Redis / Redpanda / Kafka later without touching pipeline logic.
"""

from __future__ import annotations

import asyncio
import logging
from typing import Any, Awaitable, Callable

logger = logging.getLogger(__name__)

# ── In-process queue ──────────────────────────────────────────────────────────

_queue: asyncio.Queue[Any] = asyncio.Queue()


async def enqueue(item: Any) -> None:
    """Put an item onto the queue."""
    await _queue.put(item)


async def dequeue() -> Any:
    """Get the next item from the queue (blocks until available)."""
    return await _queue.get()


def task_done() -> None:
    _queue.task_done()


def qsize() -> int:
    return _queue.qsize()


# ── Worker loop ───────────────────────────────────────────────────────────────


async def run_worker(handler: Callable[[Any], Awaitable[None]]) -> None:
    """
    Continuously consume items from the queue and call `handler(item)`.
    Designed to run as a long-lived asyncio task.
    """
    logger.info("Queue worker started.")
    while True:
        item = await dequeue()
        try:
            await handler(item)
        except Exception as exc:
            logger.error("Worker handler error: %s", exc, exc_info=True)
        finally:
            task_done()
