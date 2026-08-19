"""Small dependency-free request telemetry for operational dashboards."""

from __future__ import annotations

import time
import uuid
from collections import Counter

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response


class RequestTelemetry:
    def __init__(self) -> None:
        self.request_count = 0
        self.error_count = 0
        self.total_duration_ms = 0.0
        self.status_counts: Counter[int] = Counter()

    def snapshot(self) -> dict[str, object]:
        average = self.total_duration_ms / self.request_count if self.request_count else 0.0
        return {
            "requests": self.request_count,
            "errors": self.error_count,
            "average_duration_ms": round(average, 2),
            "status_counts": dict(self.status_counts),
        }


telemetry = RequestTelemetry()


class ObservabilityMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        started = time.perf_counter()
        request_id = request.headers.get("X-Request-ID", uuid.uuid4().hex)
        response = await call_next(request)
        elapsed_ms = (time.perf_counter() - started) * 1000
        telemetry.request_count += 1
        telemetry.total_duration_ms += elapsed_ms
        telemetry.status_counts[response.status_code] += 1
        if response.status_code >= 500:
            telemetry.error_count += 1
        response.headers["X-Request-ID"] = request_id
        response.headers["Server-Timing"] = f"app;dur={elapsed_ms:.2f}"
        return response
