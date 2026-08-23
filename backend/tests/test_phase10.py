"""
Phase 10: Notifications System
Status updates, alerts, templates, and notification delivery.
"""
import pytest
import json
from fastapi.testclient import TestClient
from backend.main import app


@pytest.fixture
def client():
    return TestClient(app)


class TestPhase10NotificationsSystem:
    """Validate notification management and delivery."""

    def test_send_notification_to_student(self, client):
        """Send a notification to a student."""
        response = client.post(
            "/api/notifications",
            json={
                "student_id": "STU001",
                "notification_type": "workflow_status",
                "title": "Workflow Status Update",
                "message": "Your withdrawal request has been submitted.",
                "priority": "normal"
            }
        )
        assert response.status_code == 200
        body = response.json()
        assert "notification_id" in body
        assert body["student_id"] == "STU001"
        assert body["status"] == "created"

    def test_notification_has_template_support(self, client):
        """Notifications can use predefined templates."""
        response = client.post(
            "/api/notifications",
            json={
                "student_id": "STU002",
                "notification_type": "workflow_status",
                "template_key": "withdrawal_submitted",
                "template_data": {"reference_no": "WD-2026-001"}
            }
        )
        assert response.status_code == 200
        body = response.json()
        assert "notification_id" in body
        assert body["status"] == "created"

    def test_retrieve_notifications_for_student(self, client):
        """Get all notifications for a student."""
        student_id = "STU003"
        
        # Send two notifications
        client.post(
            "/api/notifications",
            json={
                "student_id": student_id,
                "notification_type": "workflow_status",
                "title": "Update 1",
                "message": "First notification"
            }
        )
        client.post(
            "/api/notifications",
            json={
                "student_id": student_id,
                "notification_type": "alert",
                "title": "Update 2",
                "message": "Second notification"
            }
        )

        # Retrieve
        list_resp = client.get(f"/api/notifications?student_id={student_id}")
        assert list_resp.status_code == 200
        body = list_resp.json()
        assert isinstance(body, list)
        assert len(body) >= 2
        assert all(notif["student_id"] == student_id for notif in body)

    def test_mark_notification_as_read(self, client):
        """Mark a notification as read."""
        # Send notification
        send_resp = client.post(
            "/api/notifications",
            json={
                "student_id": "STU004",
                "notification_type": "workflow_status",
                "title": "Test",
                "message": "Test message"
            }
        )
        notification_id = send_resp.json()["notification_id"]

        # Mark as read
        read_resp = client.post(
            f"/api/notifications/{notification_id}/read"
        )
        assert read_resp.status_code == 200
        body = read_resp.json()
        assert body["read_status"] == "read"

    def test_notification_types_supported(self, client):
        """Different notification types are supported."""
        types = [
            "workflow_status",
            "alert",
            "deadline",
            "reminder",
            "approval"
        ]
        
        for notif_type in types:
            response = client.post(
                "/api/notifications",
                json={
                    "student_id": "STU005",
                    "notification_type": notif_type,
                    "title": f"{notif_type} notification",
                    "message": "Test message"
                }
            )
            assert response.status_code == 200
            body = response.json()
            assert body["notification_type"] == notif_type

    def test_notification_priority_levels(self, client):
        """Notifications support priority levels."""
        priorities = ["low", "normal", "high", "urgent"]
        
        for priority in priorities:
            response = client.post(
                "/api/notifications",
                json={
                    "student_id": "STU006",
                    "notification_type": "alert",
                    "title": f"Priority {priority}",
                    "message": "Test",
                    "priority": priority
                }
            )
            assert response.status_code == 200
            body = response.json()
            assert body["priority"] == priority

    def test_bulk_notification_to_students(self, client):
        """Send notifications to multiple students at once."""
        response = client.post(
            "/api/notifications/bulk",
            json={
                "student_ids": ["STU007", "STU008", "STU009"],
                "notification_type": "alert",
                "title": "Bulk Alert",
                "message": "This is a bulk notification"
            }
        )
        assert response.status_code == 200
        body = response.json()
        assert body["count"] == 3
        assert "notification_ids" in body

    def test_notification_filters(self, client):
        """Retrieve notifications with filters."""
        student_id = "STU010"
        
        # Send notifications of different types
        client.post(
            "/api/notifications",
            json={
                "student_id": student_id,
                "notification_type": "workflow_status",
                "title": "Status",
                "message": "Status update",
                "priority": "normal"
            }
        )
        client.post(
            "/api/notifications",
            json={
                "student_id": student_id,
                "notification_type": "alert",
                "title": "Alert",
                "message": "Alert message",
                "priority": "high"
            }
        )

        # Filter by type
        list_resp = client.get(f"/api/notifications?student_id={student_id}&type=alert")
        assert list_resp.status_code == 200
        body = list_resp.json()
        assert all(notif["notification_type"] == "alert" for notif in body)

    def test_notification_delivery_log(self, client):
        """Notifications create audit/delivery logs."""
        send_resp = client.post(
            "/api/notifications",
            json={
                "student_id": "STU001",
                "notification_type": "workflow_status",
                "title": "Test",
                "message": "Test message"
            }
        )
        notification_id = send_resp.json()["notification_id"]

        # Get delivery logs
        logs_resp = client.get(f"/api/notifications/{notification_id}/logs")
        assert logs_resp.status_code == 200
        body = logs_resp.json()
        assert isinstance(body, list)
        # Should have at least one log entry (creation)
        assert len(body) >= 1

    def test_notification_contains_metadata(self, client):
        """Notifications include metadata like timestamp and sender."""
        response = client.post(
            "/api/notifications",
            json={
                "student_id": "STU002",
                "notification_type": "workflow_status",
                "title": "Test",
                "message": "Test message"
            }
        )
        body = response.json()
        assert "created_at" in body
        assert "sent_by" in body or "sender" in body
        assert body["status"] in ["created", "pending", "sent"]
