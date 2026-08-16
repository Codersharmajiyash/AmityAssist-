"""
Phase 10: Notification Management Routes
API endpoints for notification creation, retrieval, and management.
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from ..services.notification_service import NotificationService

router = APIRouter(prefix="/api/notifications", tags=["notifications"])


class NotificationCreateRequest(BaseModel):
    student_id: str
    notification_type: str
    title: Optional[str] = None
    message: Optional[str] = None
    priority: str = "normal"
    template_key: Optional[str] = None
    template_data: Optional[Dict[str, Any]] = None


class BulkNotificationRequest(BaseModel):
    student_ids: List[str]
    notification_type: str
    title: str
    message: str
    priority: str = "normal"


@router.post("")
def create_notification(request: NotificationCreateRequest):
    """Create a new notification."""
    try:
        result = NotificationService.create_notification(
            student_id=request.student_id,
            notification_type=request.notification_type,
            title=request.title,
            message=request.message,
            priority=request.priority,
            template_key=request.template_key,
            template_data=request.template_data,
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail="Failed to create notification")


@router.get("/{notification_id}")
def get_notification(notification_id: str):
    """Retrieve a notification by ID."""
    result = NotificationService.get_notification(notification_id)
    if not result:
        raise HTTPException(status_code=404, detail="Notification not found")
    return result


@router.get("")
def list_notifications(
    student_id: str,
    type: Optional[str] = None,
    status: Optional[str] = None,
):
    """List notifications for a student with optional filters."""
    results = NotificationService.list_notifications(
        student_id=student_id,
        notification_type=type,
        read_status=status,
    )
    return results


@router.post("/{notification_id}/read")
def mark_as_read(notification_id: str):
    """Mark a notification as read."""
    result = NotificationService.mark_as_read(notification_id)
    if not result:
        raise HTTPException(status_code=404, detail="Notification not found")
    return result


@router.get("/{notification_id}/logs")
def get_delivery_logs(notification_id: str):
    """Get delivery and action logs for a notification."""
    results = NotificationService.get_delivery_logs(notification_id)
    return results


@router.post("/bulk")
def bulk_create_notifications(request: BulkNotificationRequest):
    """Create notifications for multiple students."""
    result = NotificationService.bulk_create_notifications(
        student_ids=request.student_ids,
        notification_type=request.notification_type,
        title=request.title,
        message=request.message,
        priority=request.priority,
    )
    return result
