"""
FastAPI application entry point.

Startup sequence:
  1. Database schema created and sample data seeded (lifespan hook)
  2. Rate limiter attached
  3. Security headers middleware registered
  4. CORS configured (lock down allow_origins in production)
  5. API routes mounted
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from backend.config import settings
from backend.database.seed import init_db
from backend.middleware.security import SecurityHeadersMiddleware
from backend.routes import auth, chat, documents, status, admin, student, withdrawal

limiter = Limiter(key_func=get_remote_address)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialise DB before accepting requests; cleanup on shutdown."""
    init_db()
    yield


app = FastAPI(
    title=f"{settings.app_name} API",
    description=(
        "Workflow-centric student service and procedure guidance backend for "
        "university digital front desk operations."
    ),
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url=None,
    lifespan=lifespan,
)

# ── Rate limiting ─────────────────────────────────────────────────────────────
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)  # type: ignore[arg-type]

# ── Security headers ──────────────────────────────────────────────────────────
app.add_middleware(SecurityHeadersMiddleware)

# ── CORS ──────────────────────────────────────────────────────────────────────
# In production: replace "*" with your actual front-end domain
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type"],
)

# ── Routes ────────────────────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(chat.router)
app.include_router(student.router)
app.include_router(documents.router)
app.include_router(status.router)
app.include_router(withdrawal.router)
app.include_router(admin.router)


@app.get("/api/health", tags=["System"])
async def health_check():
    """Liveness probe endpoint."""
    return {
        "status": "ok",
        "service": settings.app_name.lower(),
        "environment": settings.environment,
        "version": "1.0.0",
    }
