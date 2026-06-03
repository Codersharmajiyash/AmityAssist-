"""
Pydantic v2 request/response schemas.

Security note: Strict field validators and length limits act as a first line
of defence against malformed or oversized payloads before they reach the DB layer.
"""

from __future__ import annotations

import re
from typing import Literal, Optional

from pydantic import BaseModel, EmailStr, Field, field_validator


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------


class VerifyRequest(BaseModel):
    """Accepts either student_id OR email — at least one must be provided."""

    student_id: Optional[str] = Field(None, min_length=3, max_length=20)
    email: Optional[EmailStr] = None

    @field_validator("student_id", mode="before")
    @classmethod
    def sanitize_student_id(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        # Whitelist: alphanumeric + hyphen/underscore only.
        # Rejects SQL meta-characters: ', ", ;, --, etc.
        if not re.match(r"^[A-Za-z0-9_\-]+$", v):
            raise ValueError("student_id contains invalid characters")
        return v.upper().strip()


class VerifyResponse(BaseModel):
    verified: bool
    session_id: Optional[str] = None
    student_name: Optional[str] = None
    course: Optional[str] = None
    student_id: Optional[str] = None
    branch: Optional[str] = None
    semester: Optional[int] = None
    attendance: Optional[float] = None
    cgpa: Optional[float] = None
    fee_status: Optional[str] = None
    fee_due: Optional[float] = None
    hostel_status: Optional[str] = None
    scholarship_status: Optional[str] = None
    academic_performance: Optional[str] = None
    interests: Optional[str] = None
    message: str
    has_existing_request: bool = False
    request_status: Optional[str] = None


# ---------------------------------------------------------------------------
# Chat
# ---------------------------------------------------------------------------


class ChatRequest(BaseModel):
    session_id: str = Field(..., min_length=16, max_length=64)
    message: str = Field(..., min_length=1, max_length=2000)

    @field_validator("message", mode="before")
    @classmethod
    def strip_and_validate(cls, v: str) -> str:
        stripped = v.strip()
        if not stripped:
            raise ValueError("Message cannot be empty or whitespace only")
        return stripped


class ChatResponse(BaseModel):
    reply: str
    state: Literal[
        "ASK_REASON",
        "SUGGEST",
        "CONFIRM",
        "DONE",
        "RESOLVED",
        "INVALID",
        "ROUTED",
        "GRIEVANCE_CATEGORY",
        "GRIEVANCE_DESCRIPTION",
        "GRIEVANCE_CONFIRM",
    ]
    intent: Optional[str] = None
    sentiment: Optional[str] = None
    withdrawal_submitted: bool = False


# ---------------------------------------------------------------------------
# Student lifecycle APIs
# ---------------------------------------------------------------------------


class BackpaperRequest(BaseModel):
    student_id: str = Field(..., min_length=3, max_length=20)
    exam_id: int

    @field_validator("student_id", mode="before")
    @classmethod
    def sanitize_student_id(cls, v: str) -> str:
        if not re.match(r"^[A-Za-z0-9_\-]+$", v):
            raise ValueError("student_id contains invalid characters")
        return v.upper().strip()


class ScholarshipApply(BaseModel):
    student_id: str = Field(..., min_length=3, max_length=20)
    scholarship_id: int

    @field_validator("student_id", mode="before")
    @classmethod
    def sanitize_student_id(cls, v: str) -> str:
        if not re.match(r"^[A-Za-z0-9_\-]+$", v):
            raise ValueError("student_id contains invalid characters")
        return v.upper().strip()


class GrievanceCreate(BaseModel):
    student_id: str = Field(..., min_length=3, max_length=20)
    category: Literal["academic", "fee", "hostel", "exam", "scholarship"]
    description: str = Field(..., min_length=5, max_length=2000)

    @field_validator("student_id", mode="before")
    @classmethod
    def sanitize_student_id(cls, v: str) -> str:
        if not re.match(r"^[A-Za-z0-9_\-]+$", v):
            raise ValueError("student_id contains invalid characters")
        return v.upper().strip()

    @field_validator("description", mode="before")
    @classmethod
    def strip_description(cls, v: str) -> str:
        return v.strip()


# ---------------------------------------------------------------------------
# Admin and document APIs
# ---------------------------------------------------------------------------


class StatusUpdate(BaseModel):
    status: Literal["approved", "rejected"]


class GrievanceResolve(BaseModel):
    resolution: str = Field(..., min_length=3, max_length=2000)

    @field_validator("resolution", mode="before")
    @classmethod
    def strip_resolution(cls, v: str) -> str:
        return v.strip()


class ScholarshipApplicationUpdate(BaseModel):
    status: Literal["approved", "rejected"]


class BackpaperPaymentUpdate(BaseModel):
    status: Literal["registered", "paid"]


class DocumentVerification(BaseModel):
    status: Literal["verified", "fraud_detected", "error"]
    notes: Optional[str] = Field(None, max_length=2000)

    @field_validator("notes", mode="before")
    @classmethod
    def strip_notes(cls, v: Optional[str]) -> Optional[str]:
        return v.strip() if isinstance(v, str) else v
