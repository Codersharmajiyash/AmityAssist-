"""
Phase 10: Notification Management Service
Handle creation, delivery, templating, and logging of notifications.
"""
import json
import uuid
import string
from datetime import datetime
from typing import Dict, List, Optional, Any
from ..database.connection import get_connection


class NotificationService:
    """Manage notifications and delivery logs."""

    VALID_TYPES = [
        "workflow_status",
        "alert",
        "deadline",
        "reminder",
        "approval",
    ]
    VALID_PRIORITIES = ["low", "normal", "high", "urgent"]
    VALID_STATUSES = ["created", "pending", "sent"]

    @staticmethod
    def create_notification(
        student_id: str,
        notification_type: str,
        title: Optional[str] = None,
        message: Optional[str] = None,
        priority: str = "normal",
        template_key: Optional[str] = None,
        template_data: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Create a new notification."""
        if notification_type not in NotificationService.VALID_TYPES:
            raise ValueError(f"Invalid notification type: {notification_type}")

        if priority not in NotificationService.VALID_PRIORITIES:
            raise ValueError(f"Invalid priority: {priority}")

        notification_id = str(uuid.uuid4())
        conn = get_connection()

        # If template_key is provided, use template
        if template_key:
            row = conn.execute(
                "SELECT title_template, message_template FROM notification_templates WHERE template_key = ?",
                (template_key,),
            ).fetchone()

            if row:
                title = row["title_template"]
                message = row["message_template"]

                # Replace template variables
                if template_data:
                    formatter = string.Formatter()
                    try:
                        title = title.format(**template_data)
                        message = message.format(**template_data)
                    except KeyError:
                        # If a variable is missing, just use the raw template
                        pass

        # Ensure we have title and message
        if not title:
            title = f"Notification: {notification_type}"
        if not message:
            message = "You have a new notification."

        # Create notification record
        conn.execute(
            """INSERT INTO notifications 
               (id, student_id, notification_type, title, message, priority, template_key, template_data, read_status, sent_by, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                notification_id,
                student_id,
                notification_type,
                title,
                message,
                priority,
                template_key,
                json.dumps(template_data or {}),
                "unread",
                "system",
                datetime.now().isoformat(),
            ),
        )

        # Create initial log entry
        log_id = str(uuid.uuid4())
        conn.execute(
            """INSERT INTO notification_logs (id, notification_id, action, details, timestamp)
               VALUES (?, ?, ?, ?, ?)""",
            (
                log_id,
                notification_id,
                "created",
                "Notification created and queued for delivery",
                datetime.now().isoformat(),
            ),
        )

        conn.commit()

        return {
            "notification_id": notification_id,
            "student_id": student_id,
            "notification_type": notification_type,
            "title": title,
            "message": message,
            "priority": priority,
            "status": "created",
            "read_status": "unread",
            "sent_by": "system",
            "created_at": datetime.now().isoformat(),
        }

    @staticmethod
    def get_notification(notification_id: str) -> Optional[Dict[str, Any]]:
        """Retrieve a notification by ID."""
        conn = get_connection()

        row = conn.execute(
            "SELECT * FROM notifications WHERE id = ?", (notification_id,)
        ).fetchone()

        if not row:
            return None

        return {
            "notification_id": row["id"],
            "student_id": row["student_id"],
            "notification_type": row["notification_type"],
            "title": row["title"],
            "message": row["message"],
            "priority": row["priority"],
            "read_status": row["read_status"],
            "created_at": row["created_at"],
            "read_at": row["read_at"],
        }

    @staticmethod
    def list_notifications(
        student_id: str,
        notification_type: Optional[str] = None,
        read_status: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        """List notifications for a student with optional filters."""
        conn = get_connection()

        query = "SELECT * FROM notifications WHERE student_id = ?"
        params = [student_id]

        if notification_type:
            query += " AND notification_type = ?"
            params.append(notification_type)

        if read_status:
            query += " AND read_status = ?"
            params.append(read_status)

        query += " ORDER BY created_at DESC"

        rows = conn.execute(query, params).fetchall()

        result = []
        for row in rows:
            result.append(
                {
                    "notification_id": row["id"],
                    "student_id": row["student_id"],
                    "notification_type": row["notification_type"],
                    "title": row["title"],
                    "message": row["message"],
                    "priority": row["priority"],
                    "read_status": row["read_status"],
                    "created_at": row["created_at"],
                }
            )

        return result

    @staticmethod
    def mark_as_read(notification_id: str) -> Optional[Dict[str, Any]]:
        """Mark a notification as read."""
        conn = get_connection()

        conn.execute(
            "UPDATE notifications SET read_status = ?, read_at = ? WHERE id = ?",
            ("read", datetime.now().isoformat(), notification_id),
        )

        # Log the read action
        log_id = str(uuid.uuid4())
        conn.execute(
            """INSERT INTO notification_logs (id, notification_id, action, details, timestamp)
               VALUES (?, ?, ?, ?, ?)""",
            (
                log_id,
                notification_id,
                "read",
                "Notification marked as read by student",
                datetime.now().isoformat(),
            ),
        )

        conn.commit()

        return {
            "notification_id": notification_id,
            "read_status": "read",
        }

    @staticmethod
    def get_delivery_logs(notification_id: str) -> List[Dict[str, Any]]:
        """Get delivery and action logs for a notification."""
        conn = get_connection()

        rows = conn.execute(
            "SELECT * FROM notification_logs WHERE notification_id = ? ORDER BY timestamp",
            (notification_id,),
        ).fetchall()

        result = []
        for row in rows:
            result.append(
                {
                    "log_id": row["id"],
                    "notification_id": row["notification_id"],
                    "action": row["action"],
                    "details": row["details"],
                    "timestamp": row["timestamp"],
                }
            )

        return result

    @staticmethod
    def bulk_create_notifications(
        student_ids: List[str],
        notification_type: str,
        title: str,
        message: str,
        priority: str = "normal",
    ) -> Dict[str, Any]:
        """Create notifications for multiple students."""
        notification_ids = []
        count = 0

        for student_id in student_ids:
            try:
                result = NotificationService.create_notification(
                    student_id=student_id,
                    notification_type=notification_type,
                    title=title,
                    message=message,
                    priority=priority,
                )
                notification_ids.append(result["notification_id"])
                count += 1
            except Exception:
                # Continue with other students if one fails
                continue

        return {
            "count": count,
            "notification_ids": notification_ids,
            "created_at": datetime.now().isoformat(),
        }
