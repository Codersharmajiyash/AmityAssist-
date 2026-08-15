"""S3-compatible document storage adapter for MinIO or AWS S3."""

from __future__ import annotations

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
        extra_args = {"ContentType": content_type} if content_type else None
        try:
            kwargs = {
                "Bucket": settings.s3_bucket_documents,
                "Key": key,
                "Fileobj": body,
            }
            if extra_args:
                kwargs["ExtraArgs"] = extra_args
            self.client.upload_fileobj(**kwargs)
        except (BotoCoreError, ClientError) as exc:
            raise RuntimeError("Document storage upload failed.") from exc
        return key


storage_service = StorageService()
