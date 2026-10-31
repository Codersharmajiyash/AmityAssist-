# ==============================================================================
# UniAssist — Enterprise Amizone Sync Bridge & Outbox Engine
# Lead Architect: Abhishek Shrivastava
# Phase 3: Bidirectional Event-Driven Sync with Offline Outbox Queue
# ==============================================================================
from __future__ import annotations

import hashlib
import hmac
import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import httpx

from ..database.connection import get_connection
from ..config import settings

logger = logging.getLogger("uniassist.sync")

# Secret shared between Amizone IT and UniAssist for HMAC verification
AMIZONE_SHARED_SECRET = getattr(
    settings, "amizone_shared_secret", "amizone_enterprise_hmac_secret_2026"
)
AMIZONE_API_ENDPOINT = getattr(
    settings, "amizone_api_endpoint", "https://api.amity.edu/amizone/v1/events"
)


class SyncBridgeService:

    # ── Table Initialisation ──────────────────────────────────────────────────

    @classmethod
    def init_tables(cls) -> None:
        """Creates the resilient Outbox table and Inbound Event Log if not present."""
        conn = get_connection()
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS sync_outbox (
                id          TEXT PRIMARY KEY,
                event_type  TEXT NOT NULL,
                aggregate_id TEXT NOT NULL,
                payload     TEXT NOT NULL,
                status      TEXT NOT NULL DEFAULT 'PENDING',
                retry_count INTEGER DEFAULT 0,
                last_error  TEXT,
                created_at  TEXT NOT NULL,
                synced_at   TEXT
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_outbox_status ON sync_outbox(status)"
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS sync_inbound_log (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                event_type  TEXT NOT NULL,
                aggregate_id TEXT,
                payload     TEXT NOT NULL,
                result      TEXT,
                received_at TEXT NOT NULL
            )
            """
        )
        conn.commit()

    # ── Helpers ───────────────────────────────────────────────────────────────

    @staticmethod
    def _now_iso() -> str:
        return datetime.now(timezone.utc).isoformat()

    # ── HMAC-SHA256 Cryptographic Signing ─────────────────────────────────────

    @classmethod
    def generate_hmac_signature(cls, payload_bytes: bytes) -> str:
        """Generates an HMAC-SHA256 signature for tamper-evident webhooks."""
        return hmac.new(
            AMIZONE_SHARED_SECRET.encode("utf-8"),
            payload_bytes,
            hashlib.sha256,
        ).hexdigest()

    @classmethod
    def verify_hmac_signature(cls, payload_bytes: bytes, incoming_signature: str) -> bool:
        """Verifies that an incoming webhook legitimately originated from Amizone."""
        expected = cls.generate_hmac_signature(payload_bytes)
        return hmac.compare_digest(expected, incoming_signature)

    # ── Outbound Queue Management ─────────────────────────────────────────────

    @classmethod
    def queue_outbound_event(
        cls,
        event_type: str,
        aggregate_id: str,
        payload_data: Dict[str, Any],
    ) -> str:
        """
        Enqueues an event into the local Outbox table.

        Guarantees transactional consistency before attempting network calls.
        The event is persisted immediately — even if Amizone is offline, the
        record survives server restarts and is retried on the next flush.

        Returns:
            event_id: Unique identifier for the queued event (EVT-XXXXXXXXXXXX).
        """
        cls.init_tables()
        conn = get_connection()
        event_id = f"EVT-{uuid.uuid4().hex[:12].upper()}"
        now = cls._now_iso()
        full_payload = {
            "event_id": event_id,
            "event_type": event_type,
            "aggregate_id": aggregate_id,
            "timestamp": now,
            "data": payload_data,
        }
        conn.execute(
            """
            INSERT INTO sync_outbox (id, event_type, aggregate_id, payload, status, created_at)
            VALUES (?, ?, ?, ?, 'PENDING', ?)
            """,
            (event_id, event_type, aggregate_id, json.dumps(full_payload), now),
        )
        conn.commit()
        logger.info(
            "Outbox event queued: %s for aggregate %s (Event: %s)",
            event_type,
            aggregate_id,
            event_id,
        )
        return event_id

    @classmethod
    async def flush_outbox(cls, max_batch: int = 20) -> Dict[str, Any]:
        """
        Processes pending outbox events and pushes them to Amizone via HTTPS.

        If Amizone is down, safely increments retry_count (max 5) without
        crashing. Events exceeding 5 retries are left in FAILED state for
        IT staff investigation via the health cockpit.

        Returns:
            dict with keys: processed, success, failed
        """
        cls.init_tables()
        conn = get_connection()
        rows = conn.execute(
            """
            SELECT id, event_type, payload, retry_count
            FROM sync_outbox
            WHERE status IN ('PENDING', 'FAILED') AND retry_count < 5
            ORDER BY created_at ASC
            LIMIT ?
            """,
            (max_batch,),
        ).fetchall()

        if not rows:
            return {"processed": 0, "success": 0, "failed": 0}

        success_count = 0
        failed_count = 0

        async with httpx.AsyncClient(timeout=10.0) as client:
            for row in rows:
                event_id = row["id"]
                payload_str = row["payload"]
                payload_bytes = payload_str.encode("utf-8")
                sig = cls.generate_hmac_signature(payload_bytes)
                headers = {
                    "Content-Type": "application/json",
                    "X-UniAssist-Signature": sig,
                    "X-UniAssist-Event-Id": event_id,
                }
                try:
                    response = await client.post(
                        AMIZONE_API_ENDPOINT,
                        content=payload_bytes,
                        headers=headers,
                    )
                    if response.status_code in (200, 201, 202):
                        now = cls._now_iso()
                        conn.execute(
                            """
                            UPDATE sync_outbox
                            SET status = 'SYNCED', synced_at = ?, last_error = NULL
                            WHERE id = ?
                            """,
                            (now, event_id),
                        )
                        success_count += 1
                        logger.info("Outbox event %s synced to Amizone successfully.", event_id)
                    else:
                        raise RuntimeError(
                            f"Amizone returned HTTP {response.status_code}: {response.text[:200]}"
                        )
                except Exception as ex:
                    logger.warning(
                        "Failed to sync event %s to Amizone: %s", event_id, str(ex)
                    )
                    conn.execute(
                        """
                        UPDATE sync_outbox
                        SET status = 'FAILED',
                            retry_count = retry_count + 1,
                            last_error = ?
                        WHERE id = ?
                        """,
                        (str(ex)[:400], event_id),
                    )
                    failed_count += 1

        conn.commit()
        return {"processed": len(rows), "success": success_count, "failed": failed_count}

    # ── Outbox Query Helpers ──────────────────────────────────────────────────

    @classmethod
    def get_outbox_counts(cls) -> Dict[str, int]:
        cls.init_tables()
        conn = get_connection()
        pending = conn.execute(
            "SELECT COUNT(*) AS c FROM sync_outbox WHERE status = 'PENDING'"
        ).fetchone()["c"]
        synced = conn.execute(
            "SELECT COUNT(*) AS c FROM sync_outbox WHERE status = 'SYNCED'"
        ).fetchone()["c"]
        failed = conn.execute(
            "SELECT COUNT(*) AS c FROM sync_outbox WHERE status = 'FAILED'"
        ).fetchone()["c"]
        return {"pending": pending, "synced": synced, "failed": failed}

    @classmethod
    def get_recent_events(cls, limit: int = 10) -> List[Dict[str, Any]]:
        cls.init_tables()
        conn = get_connection()
        rows = conn.execute(
            """
            SELECT id, event_type, aggregate_id, status, retry_count,
                   last_error, created_at, synced_at
            FROM sync_outbox
            ORDER BY created_at DESC
            LIMIT ?
            """,
            (limit,),
        ).fetchall()
        return [dict(r) for r in rows]

    # ── Inbound Webhook Processing (From Amizone) ─────────────────────────────

    @classmethod
    def process_inbound_amizone_event(cls, payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Handles incoming events from Amizone and updates the local UniAssist database.

        Supported event_type values:
          - STUDENT_ENROLLED          : Creates/updates student roster record.
          - FEE_PAID                  : Logs a fee payment record.
          - NOTICE_PUBLISHED          : Adds university circular to notice feed.
          - STUDENT_STATUS_CHANGED    : Syncs probation or suspension flags.
        """
        cls.init_tables()
        conn = get_connection()
        event_type = payload.get("event_type", "").upper()
        data = payload.get("data", {})
        received_at = cls._now_iso()
        result: Dict[str, Any] = {}

        if event_type == "STUDENT_ENROLLED":
            s_id = str(data.get("student_id", "")).upper().strip()
            name = data.get("name") or "Enrolled Student"
            program = data.get("program") or data.get("course") or "Undergraduate"
            semester = int(data.get("semester", 1))
            email = data.get("email") or f"{s_id.lower()}@amity.edu"
            branch = data.get("branch") or "General"
            enrolled_date = data.get("enrolled_date") or cls._now_iso()[:10]

            conn.execute(
                """
                INSERT INTO students (id, name, email, course, branch, semester, enrolled_date)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name     = excluded.name,
                    course   = excluded.course,
                    semester = excluded.semester
                """,
                (s_id, name, email, program, branch, semester, enrolled_date),
            )
            conn.commit()
            result = {
                "status": "success",
                "message": f"Student {s_id} enrolled/updated in local roster.",
            }

        elif event_type == "NOTICE_PUBLISHED":
            title = data.get("title", "")
            body = data.get("content", "")
            cat = str(data.get("category", "general")).lower().strip()
            if cat not in ("academics", "exam", "scholarship", "internship", "general"):
                cat = "general"
            target_branch = data.get("target_branch", "ALL")
            target_semester = int(data.get("target_semester", 0))
            conn.execute(
                """
                INSERT INTO notices (title, content, target_branch, target_semester, category, timestamp)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (title, body, target_branch, target_semester, cat, received_at),
            )
            conn.commit()
            result = {
                "status": "success",
                "message": f"Notice '{title}' synced to UniAssist notice feed.",
            }

        elif event_type == "STUDENT_STATUS_CHANGED":
            s_id = str(data.get("student_id", "")).upper().strip()
            new_status = data.get("status", "ACTIVE")
            conn.execute(
                "UPDATE students SET status = ? WHERE id = ?",
                (new_status, s_id),
            )
            conn.commit()
            result = {
                "status": "success",
                "message": f"Status for {s_id} updated to '{new_status}'.",
            }

        elif event_type == "FEE_PAID":
            s_id = str(data.get("student_id", "")).upper().strip()
            amount = data.get("amount", 0.0)
            receipt_no = data.get("receipt_no", "")
            try:
                conn.execute(
                    """
                    INSERT INTO notifications (student_id, title, message, category, timestamp)
                    VALUES (?, ?, ?, 'FINANCE', ?)
                    """,
                    (
                        s_id,
                        "Fee Payment Confirmed (Amizone Sync)",
                        f"Fee payment of ₹{amount:,.2f} recorded. Receipt: {receipt_no}.",
                        received_at,
                    ),
                )
                conn.commit()
            except Exception:
                pass  # notifications table may not exist in all environments
            result = {
                "status": "success",
                "message": f"Fee payment of ₹{amount} for {s_id} logged.",
            }

        else:
            result = {
                "status": "ignored",
                "message": f"Unhandled event type '{event_type}'.",
            }

        # Persist inbound log for audit trail
        try:
            conn.execute(
                """
                INSERT INTO sync_inbound_log (event_type, aggregate_id, payload, result, received_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                (
                    event_type,
                    data.get("student_id", payload.get("aggregate_id", "")),
                    json.dumps(payload),
                    json.dumps(result),
                    received_at,
                ),
            )
            conn.commit()
        except Exception as log_err:
            logger.warning("Could not write inbound log: %s", log_err)

        return result

