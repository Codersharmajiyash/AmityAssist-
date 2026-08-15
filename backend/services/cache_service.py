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

    @property
    def client(self) -> Redis:
        if self._client is None:
            self._client = Redis.from_url(settings.redis_url, decode_responses=True)
        return self._client

    def get_json(self, key: str) -> Any | None:
        try:
            value = self.client.get(key)
        except RedisError:
            return None
        return json.loads(value) if value else None

    def set_json(self, key: str, value: Any, ttl_seconds: int = 300) -> None:
        try:
            self.client.setex(key, ttl_seconds, json.dumps(value))
        except RedisError:
            return


cache_service = CacheService()
