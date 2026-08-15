"""Role-based access control helpers."""

from __future__ import annotations

from fastapi import HTTPException, status


ROLE_PERMISSIONS: dict[str, set[str]] = {
    "Student": {
        "withdrawal:read",
        "withdrawal:create",
        "documents:upload",
        "profile:read",
    },
    "Department Coordinator": {
        "withdrawal:read",
        "clearance:update",
        "grievance:update",
    },
    "Registrar": {
        "withdrawal:read",
        "withdrawal:update",
        "procedure:manage",
    },
    "Finance Department": {
        "withdrawal:read",
        "refund:update",
        "clearance:update",
    },
    "Administrator": {
        "withdrawal:read",
        "withdrawal:update",
        "procedure:manage",
        "users:manage",
        "audit:read",
    },
}


def ensure_permission(role: str, permission: str) -> None:
    if permission not in ROLE_PERMISSIONS.get(role, set()):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to perform this action.",
        )
