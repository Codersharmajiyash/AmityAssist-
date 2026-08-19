"""Phase 11 reporting queries and lightweight export helpers."""

from __future__ import annotations

import csv
import io
from datetime import datetime, timezone
from typing import Any

from ..database.connection import get_connection


class ReportingService:
    """Provide read-only operational reports for staff dashboards."""

    @staticmethod
    def analytics_snapshot() -> dict[str, Any]:
        conn = get_connection()
        scalar = lambda sql: conn.execute(sql).fetchone()[0]
        return {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "students": scalar("SELECT COUNT(*) FROM students"),
            "workflows": scalar("SELECT COUNT(*) FROM workflows"),
            "withdrawal_requests": scalar("SELECT COUNT(*) FROM withdrawal_requests"),
            "open_grievances": scalar("SELECT COUNT(*) FROM grievances WHERE status != 'resolved'"),
            "pending_documents": scalar("SELECT COUNT(*) FROM documents WHERE verification_status = 'pending'"),
            "unread_notifications": scalar("SELECT COUNT(*) FROM notifications WHERE read_status = 'unread'"),
        }

    @staticmethod
    def journey_funnel() -> dict[str, Any]:
        conn = get_connection()
        rows = conn.execute(
            "SELECT status, COUNT(*) AS count FROM workflows GROUP BY status ORDER BY count DESC, status"
        ).fetchall()
        total = sum(row["count"] for row in rows)
        stages = [
            {
                "status": row["status"],
                "count": row["count"],
                "share_of_workflows": round((row["count"] / total) * 100, 2) if total else 0,
            }
            for row in rows
        ]
        return {"total_workflows": total, "stages": stages}

    @staticmethod
    def bottlenecks() -> dict[str, Any]:
        conn = get_connection()
        rows = conn.execute(
            """SELECT COALESCE(assigned_department, 'Unassigned') AS department,
                      status, COUNT(*) AS active_workflows,
                      MIN(created_at) AS oldest_created_at
               FROM workflows
               WHERE status NOT IN ('completed', 'resolved', 'approved', 'rejected')
               GROUP BY COALESCE(assigned_department, 'Unassigned'), status
               ORDER BY active_workflows DESC, oldest_created_at ASC"""
        ).fetchall()
        items = [dict(row) for row in rows]
        return {
            "total_active_workflows": sum(item["active_workflows"] for item in items),
            "bottlenecks": items,
        }

    @staticmethod
    def csv_export(report: dict[str, Any]) -> bytes:
        output = io.StringIO(newline="")
        writer = csv.writer(output)
        if "stages" in report:
            writer.writerow(["status", "count", "share_of_workflows"])
            writer.writerows([[s["status"], s["count"], s["share_of_workflows"]] for s in report["stages"]])
        elif "bottlenecks" in report:
            writer.writerow(["department", "status", "active_workflows", "oldest_created_at"])
            writer.writerows([[b["department"], b["status"], b["active_workflows"], b["oldest_created_at"]] for b in report["bottlenecks"]])
        else:
            writer.writerow(["metric", "value"])
            writer.writerows([[key, value] for key, value in report.items()])
        return output.getvalue().encode("utf-8")

    @staticmethod
    def pdf_export(title: str, report: dict[str, Any]) -> bytes:
        """Create a small, valid PDF summary without an external PDF package."""
        lines = [title, ""]
        for key, value in report.items():
            if isinstance(value, list):
                lines.append(f"{key}: {len(value)} records")
            else:
                lines.append(f"{key}: {value}")
        def escape_pdf_text(value: object) -> str:
            return str(value).replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")

        text_operations = [f"({escape_pdf_text(line)}) Tj 0 -18 Td" for line in lines]
        content = "BT /F1 12 Tf 50 760 Td " + " ".join(text_operations) + " ET"
        objects = [
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
            f"<< /Length {len(content.encode('latin-1', 'replace'))} >>\nstream\n{content}\nendstream",
        ]
        pdf = "%PDF-1.4\n"
        offsets = [0]
        for index, obj in enumerate(objects, 1):
            offsets.append(len(pdf.encode("latin-1")))
            pdf += f"{index} 0 obj\n{obj}\nendobj\n"
        xref_offset = len(pdf.encode("latin-1"))
        pdf += f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n"
        pdf += "".join(f"{offset:010d} 00000 n \n" for offset in offsets[1:])
        pdf += f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref_offset}\n%%EOF\n"
        return pdf.encode("latin-1", "replace")
