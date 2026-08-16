"""S3-compatible document storage adapter for MinIO or AWS S3."""

from __future__ import annotations

from pathlib import Path
from typing import BinaryIO

import boto3
from botocore.exceptions import BotoCoreError, ClientError

from ..config import settings


class StorageService:
    def __init__(self) -> None:
        self._client = None

    @property
    def client(self):
        if self._client is None:
            self._client = boto3.client(
                "s3",
                endpoint_url=settings.s3_endpoint_url,
                aws_access_key_id=settings.s3_access_key,
                aws_secret_access_key=settings.s3_secret_key,
            )
        return self._client

    def upload_document(self, key: str, body: BinaryIO, content_type: str | None = None) -> str:
        data = body.read() if hasattr(body, "read") else b""
        from io import BytesIO
        try:
            extra_args = {"ContentType": content_type} if content_type else None
            kwargs = {
                "Bucket": settings.s3_bucket_documents,
                "Key": key,
                "Fileobj": BytesIO(data),
            }
            if extra_args:
                kwargs["ExtraArgs"] = extra_args
            self.client.upload_fileobj(**kwargs)
            return key
        except Exception:
            local_root = Path(__file__).resolve().parents[2] / "uploads"
            local_root.mkdir(parents=True, exist_ok=True)
            target = local_root / key
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            return key

    def read_document(self, key: str) -> bytes:
        try:
            response = self.client.get_object(Bucket=settings.s3_bucket_documents, Key=key)
            return response["Body"].read()
        except (BotoCoreError, ClientError, OSError, ValueError):
            local_root = Path(__file__).resolve().parents[2] / "uploads"
            target = local_root / key
            if not target.exists():
                raise FileNotFoundError(f"Document not found in local fallback storage: {key}")
            return target.read_bytes()


storage_service = StorageService()
