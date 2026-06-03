"""
Security response headers middleware.

Headers applied to every response:
  X-Content-Type-Options   → Prevent MIME-type sniffing (XSS vector)
  X-Frame-Options          → Prevent clickjacking via iframe embedding
  X-XSS-Protection         → Legacy XSS filter for older browsers
  Referrer-Policy          → Limit referrer information leakage
  Permissions-Policy       → Deny access to sensitive browser APIs
  Content-Security-Policy  → Whitelist trusted content sources
"""

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        response: Response = await call_next(request)

        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = (
            "geolocation=(), microphone=(), camera=(), payment=()"
        )
        # CSP: allow inline styles/scripts only for the local frontend (dev).
        # In production, replace 'unsafe-inline' with a nonce-based approach.
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; "
            "script-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://fonts.gstatic.com; "
            "font-src 'self' https://fonts.gstatic.com; "
            "img-src 'self' data:; "
            "connect-src 'self' http://localhost:8000;"
        )
        return response
