"""
Phase 9: Workflow Management Service
Generic workflow engine for handling procedures, checklists, and status progression.
"""
import json
import uuid
import random
from datetime import datetime
from typing import Dict, List, Optional, Any
from ..database.connection import get_connection


class WorkflowService:
    """Manage generic workflows for any procedure type."""

    # Procedure type to department mapping and checklist templates
    PROCEDURE_CONFIG = {
        "withdrawal": {
            "default_department": "Academic Affairs",
            "status_flow": [
                "initiated",
                "submitted",
                "under_review",
                "department_clearance",
                "finance_processing",
                "completed",
            ],
            "checklist_template": [
                "Withdrawal Application Form",
                "Student ID Proof",
                "Fee Clearance Statement",
                "Library Clearance",
            ],
        },
        "grievance": {
            "default_department": "Student Services",
            "status_flow": ["initiated", "submitted", "under_review", "resolved"],
            "checklist_template": [
                "Grievance Description",
                "Supporting Documents",
                "Resolution Confirmation",
            ],
        },
        "scholarship": {
            "default_department": "Finance",
            "status_flow": ["initiated", "submitted", "under_review", "approved"],
            "checklist_template": [
                "Scholarship Application Form",
                "Academic Transcript",
                "Eligibility Verification",
            ],
        },
    }

    @staticmethod
    def create_workflow(
        procedure_type: str,
        student_id: str,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Create a new workflow instance."""
        if procedure_type not in WorkflowService.PROCEDURE_CONFIG:
            raise ValueError(f"Unknown procedure type: {procedure_type}")

        workflow_id = str(uuid.uuid4())
        config = WorkflowService.PROCEDURE_CONFIG[procedure_type]
        assigned_dept = config["default_department"]

        # Create workflow record
        conn = get_connection()
        conn.execute(
            """INSERT INTO workflows 
               (id, student_id, procedure_type, status, assigned_department, metadata, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                workflow_id,
                student_id,
                procedure_type,
                "initiated",
                assigned_dept,
                json.dumps(metadata or {}),
                datetime.now().isoformat(),
                datetime.now().isoformat(),
            ),
        )
        conn.commit()

        # Generate and insert checklist items
        checklist = WorkflowService._generate_checklist(
            workflow_id, procedure_type
        )

        return {
            "workflow_id": workflow_id,
            "procedure_type": procedure_type,
            "student_id": student_id,
            "status": "initiated",
            "assigned_department": assigned_dept,
            "checklist": checklist,
            "created_at": datetime.now().isoformat(),
        }

    @staticmethod
    def _generate_checklist(workflow_id: str, procedure_type: str) -> List[Dict]:
        """Generate checklist items for a workflow based on procedure type."""
        config = WorkflowService.PROCEDURE_CONFIG.get(procedure_type, {})
        template = config.get("checklist_template", [])

        checklist = []
        conn = get_connection()

        for i, description in enumerate(template, 1):
            item_id = str(uuid.uuid4())
            conn.execute(
                """INSERT INTO workflow_checklist_items 
                   (id, workflow_id, item_number, description, status, created_at, updated_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?)""",
                (
                    item_id,
                    workflow_id,
                    i,
                    description,
                    "pending",
                    datetime.now().isoformat(),
                    datetime.now().isoformat(),
                ),
            )

            checklist.append(
                {
                    "item_id": item_id,
                    "description": description,
                    "status": "pending",
                }
            )

        conn.commit()
        return checklist

    @staticmethod
    def get_workflow(workflow_id: str) -> Optional[Dict[str, Any]]:
        """Retrieve a workflow by ID with current status and checklist."""
        conn = get_connection()

        # Get workflow
        row = conn.execute(
            "SELECT * FROM workflows WHERE id = ?", (workflow_id,)
        ).fetchone()

        if not row:
            return None

        # Get checklist items
        checklist_rows = conn.execute(
            "SELECT id, description, status FROM workflow_checklist_items WHERE workflow_id = ? ORDER BY item_number",
            (workflow_id,),
        ).fetchall()

        checklist = [
            {
                "item_id": item["id"],
                "description": item["description"],
                "status": item["status"],
            }
            for item in checklist_rows
        ]

        return {
            "workflow_id": row["id"],
            "procedure_type": row["procedure_type"],
            "student_id": row["student_id"],
            "status": row["status"],
            "assigned_department": row["assigned_department"],
            "checklist": checklist,
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }

    @staticmethod
    def list_workflows_for_student(student_id: str) -> List[Dict[str, Any]]:
        """List all workflows for a student."""
        conn = get_connection()

        workflows_rows = conn.execute(
            "SELECT * FROM workflows WHERE student_id = ? ORDER BY created_at DESC",
            (student_id,),
        ).fetchall()

        result = []
        for row in workflows_rows:
            # Get checklist for each workflow
            checklist_rows = conn.execute(
                "SELECT id, description, status FROM workflow_checklist_items WHERE workflow_id = ? ORDER BY item_number",
                (row["id"],),
            ).fetchall()

            checklist = [
                {
                    "item_id": item["id"],
                    "description": item["description"],
                    "status": item["status"],
                }
                for item in checklist_rows
            ]

            result.append(
                {
                    "workflow_id": row["id"],
                    "procedure_type": row["procedure_type"],
                    "student_id": row["student_id"],
                    "status": row["status"],
                    "assigned_department": row["assigned_department"],
                    "checklist": checklist,
                    "created_at": row["created_at"],
                }
            )

        return result

    @staticmethod
    def advance_workflow(
        workflow_id: str, action: str, notes: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """Advance workflow to next status."""
        conn = get_connection()

        row = conn.execute(
            "SELECT * FROM workflows WHERE id = ?", (workflow_id,)
        ).fetchone()

        if not row:
            return None

        # Get configuration for this procedure
        config = WorkflowService.PROCEDURE_CONFIG.get(row["procedure_type"], {})
        status_flow = config.get("status_flow", [])

        current_idx = status_flow.index(row["status"]) if row["status"] in status_flow else 0
        next_idx = min(current_idx + 1, len(status_flow) - 1)
        next_status = status_flow[next_idx]

        # Update workflow status
        conn.execute(
            "UPDATE workflows SET status = ?, updated_at = ? WHERE id = ?",
            (next_status, datetime.now().isoformat(), workflow_id),
        )
        conn.commit()

        return WorkflowService.get_workflow(workflow_id)

    @staticmethod
    def complete_checklist_item(
        workflow_id: str, item_id: str, notes: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """Mark a checklist item as completed."""
        conn = get_connection()

        # Update item status
        conn.execute(
            "UPDATE workflow_checklist_items SET status = ?, notes = ?, updated_at = ? WHERE id = ? AND workflow_id = ?",
            ("completed", notes, datetime.now().isoformat(), item_id, workflow_id),
        )
        conn.commit()

        return WorkflowService.get_workflow(workflow_id)
