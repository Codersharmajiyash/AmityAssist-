"""Environment-based settings for the UNIASSIST target stack."""

from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    app_name: str = "UNIASSIST"
    environment: str = os.getenv("UNIASSIST_ENV", "development")
    api_prefix: str = "/api"

    database_url: str = os.getenv(
        "DATABASE_URL",
        "postgresql+asyncpg://uniassist:uniassist@localhost:5432/uniassist",
    )
    redis_url: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")

    jwt_secret_key: str = os.getenv("JWT_SECRET_KEY", "change-me-in-production")
    jwt_algorithm: str = os.getenv("JWT_ALGORITHM", "HS256")
    access_token_minutes: int = int(os.getenv("ACCESS_TOKEN_MINUTES", "30"))

    s3_endpoint_url: str = os.getenv("S3_ENDPOINT_URL", "http://localhost:9000")
    s3_access_key: str = os.getenv("S3_ACCESS_KEY", "minioadmin")
    s3_secret_key: str = os.getenv("S3_SECRET_KEY", "minioadmin")
    s3_bucket_documents: str = os.getenv("S3_BUCKET_DOCUMENTS", "uniassist-documents")

    cors_origins: tuple[str, ...] = tuple(
        origin.strip()
        for origin in os.getenv(
            "CORS_ORIGINS",
            "http://localhost:3000,http://localhost:8080,http://localhost:5500,http://127.0.0.1:5500",
        ).split(",")
        if origin.strip()
    )


settings = Settings()
