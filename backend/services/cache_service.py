"""Redis cache adapter with graceful local fallback."""

from __future__ import annotations

import json
from typing import Any

from redis import Redis
from redis.exceptions import RedisError

from ..config import settings


class CacheService:
    def __init__(self) -> None:
        self._client: Redis | None = None
        self._memory_cache: dict[str, tuple[Any, float]] = {}

    @property
    def client(self) -> Redis:
        if self._client is None:
            self._client = Redis.from_url(
                settings.redis_url,
                decode_responses=True,
                socket_connect_timeout=0.5,
                socket_timeout=0.5,
            )
        return self._client

    def get_json(self, key: str) -> Any | None:
        try:
            value = self.client.get(key)
            if value is not None:
                return json.loads(value)
        except (RedisError, OSError):
            pass

        entry = self._memory_cache.get(key)
        if entry is None:
            return None

        payload, expires_at = entry
        if expires_at < __import__("time").time():
            self._memory_cache.pop(key, None)
            return None
        return payload

    def set_json(self, key: str, value: Any, ttl_seconds: int = 300) -> None:
        try:
            self.client.setex(key, ttl_seconds, json.dumps(value))
            return
        except (RedisError, OSError):
            pass

        expires_at = __import__("time").time() + ttl_seconds
        self._memory_cache[key] = (value, expires_at)


cache_service = CacheService()
