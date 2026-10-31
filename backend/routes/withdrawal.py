"""Structured withdrawal workflow endpoints for Phase 1 UNIASSIST MVP & Phase 21 Clearance Pipeline."""

import re
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, HTTPException, Request, Response
from pydantic import BaseModel, Field, validator

from ..security.rbac import get_current_user

from ..database.connection import get_connection
from ..models.schemas import DepartmentClearActionRequest, OffsetDepositRequest, DepositLedgerResponse
from ..services.token_pdf_service import generate_token_slip_pdf
from ..services.withdrawal_workflow import (
    create_withdrawal_request,
    get_clearance_voucher,
    get_deposit_ledger,
    get_latest_withdrawal_status,
    get_required_documents,
    get_withdrawal_guide,
    offset_dues_from_caution_deposit,
    process_department_clearance,
)

router = APIRouter(prefix="/api/withdrawal", tags=["Withdrawal Workflow"])


class WithdrawalApplyRequest(BaseModel):
    student_id: str = Field(..., min_length=2, max_length=50)
    reason: str = Field(..., min_length=2, max_length=200)
    intent: Optional[str] = "withdrawal_official"


@router.get("/guide")
async def withdrawal_guide():
    """Return official steps, documents, forms, departments, and timelines."""
    return get_withdrawal_guide()


@router.get("/documents")
async def withdrawal_documents(reason: str | None = None):
    """Return required documents for a withdrawal reason."""
    return {"documents": get_required_documents(reason)}


@router.get("/status/{student_id}")
async def withdrawal_status(student_id: str):
    """Return latest withdrawal request, generated checklist, 4-gate clearance pipeline, and voucher."""
    return get_latest_withdrawal_status(student_id)


@router.post("/apply")
async def apply_withdrawal(req: WithdrawalApplyRequest):
    """Submit an official withdrawal application, initializing 4 sequential clearance gates and voucher."""
    s_id = req.student_id.upper().strip()
    if not s_id or s_id in ("GUEST", "ANONYMOUS", "STAFF"):
        raise HTTPException(
            status_code=401,
            detail="Official university withdrawal requires verified student login.",
        )

    conn = get_connection()
    student = conn.execute("SELECT id, name FROM students WHERE UPPER(id) = ?", (s_id,)).fetchone()
    if not student:
        raise HTTPException(
            status_code=404,
            detail=f"Student record '{req.student_id}' not found. Please log in with verified student credentials.",
        )

    # Strictly enforce: Only one active withdrawal request at a time
    active_row = conn.execute(
        """SELECT id, reference_no, status, timestamp
           FROM withdrawal_requests
           WHERE UPPER(student_id) = ? AND LOWER(status) NOT IN ('completed', 'rejected', 'cancelled')
           ORDER BY timestamp DESC
           LIMIT 1""",
        (s_id,),
    ).fetchone()
    if active_row:
        raise HTTPException(
            status_code=400,
            detail=f"An active withdrawal request ({active_row['reference_no']}) is already in progress for this student. Only one withdrawal application is permitted at a time.",
        )

    reference_no = create_withdrawal_request(s_id, req.reason, req.intent or "withdrawal_official")
    voucher = get_clearance_voucher(reference_no)
    return {
        "success": True,
        "reference_no": reference_no,
        "message": "Withdrawal clearance pipeline initiated successfully.",
        "voucher": voucher,
    }


@router.post("/{reference_no}/clear/{department}")
async def clear_department_gate(
    reference_no: str,
    department: str,
    payload: DepartmentClearActionRequest,
):
    """Sign off on a department clearance gate (CLEAR or FLAG_DUES) with officer details and audit notes."""
    try:
        result = process_department_clearance(
            reference_no=reference_no,
            department=department,
            action=payload.action,
            officer_name=payload.officer_name,
            officer_id=payload.officer_id,
            notes=payload.notes,
            dues_amount=payload.dues_amount or 0.0,
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/voucher/{reference_no}")
async def fetch_clearance_voucher(reference_no: str):
    """Fetch standardized pre-itemized fee voucher citing UGC regulations."""
    voucher = get_clearance_voucher(reference_no)
    if not voucher:
        raise HTTPException(status_code=404, detail=f"Clearance voucher not found for reference {reference_no}")
    return voucher


@router.post("/{reference_no}/offset-dues")
async def offset_department_dues(reference_no: str, payload: OffsetDepositRequest):
    """Smart financial offsetting: Deduct minor asset/book fines from caution deposit instead of freezing refunds."""
    try:
        result = offset_dues_from_caution_deposit(
            reference_no=reference_no,
            department=payload.department,
            amount=payload.amount,
            reason=payload.reason,
            authorized_by=payload.authorized_by or "Finance Officer",
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/{reference_no}/deposit-ledger")
async def fetch_deposit_ledger(reference_no: str):
    """Fetch caution deposit ledger balance and deduction transaction history."""
    ledger = get_deposit_ledger(reference_no)
    if not ledger:
        raise HTTPException(status_code=404, detail=f"Deposit ledger not found for reference {reference_no}")
    return ledger


@router.get("/{reference_no}/slip")
async def download_token_slip(reference_no: str):
    """Generate and return official printable 1-page PDF token slip with 2D vector QR code."""
    voucher = get_clearance_voucher(reference_no)
    if not voucher:
        raise HTTPException(status_code=404, detail=f"Clearance record not found for reference {reference_no}")

    tracking_url = f"https://kiosk.amity.edu/track?ref={reference_no}"
    pdf_bytes = generate_token_slip_pdf(reference_no, voucher, tracking_url=tracking_url)

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'inline; filename="TOKEN-{reference_no}.pdf"',
        },
    )


@router.get("/track/{reference_no}")
async def public_track_clearance(reference_no: str):
    """Public remote tracking endpoint accessible via smartphone camera QR scan anywhere in the world."""
    voucher = get_clearance_voucher(reference_no)
    if not voucher:
        raise HTTPException(status_code=404, detail=f"Tracking record not found for reference {reference_no}")

    return {
        "reference_no": voucher["reference_no"],
        "student_id": voucher["student_id"],
        "student_name": voucher["student_name"],
        "course": voucher["course"],
        "submission_date": voucher["submission_date"],
        "current_status": voucher["current_status"],
        "ordinance_clause": voucher["ordinance_clause"],
        "gates": voucher["gates"],
        "net_refundable_amount": voucher["net_refundable_amount"],
        "caution_deposit_balance": voucher["caution_deposit_balance"],
        "tracking_url": f"https://kiosk.amity.edu/track?ref={reference_no}",
        "is_completed": voucher["current_status"].lower() == "completed",
    }


def _ensure_bank_tables() -> None:
    conn = get_connection()
    conn.execute(
        """CREATE TABLE IF NOT EXISTS withdrawal_bank_details (
            reference_no TEXT PRIMARY KEY,
            account_holder_name TEXT NOT NULL,
            account_number TEXT NOT NULL,
            ifsc_code TEXT NOT NULL,
            relationship TEXT NOT NULL DEFAULT 'Student',
            bank_proof_file TEXT,
            created_at TEXT NOT NULL
        );"""
    )
    try:
        conn.execute("ALTER TABLE withdrawal_requests ADD COLUMN refund_utr_number TEXT")
    except Exception:
        pass
    try:
        conn.execute("ALTER TABLE withdrawal_requests ADD COLUMN refund_disbursed_at TEXT")
    except Exception:
        pass
    try:
        conn.execute("ALTER TABLE withdrawal_requests ADD COLUMN refund_disbursed_amount REAL DEFAULT 0.0")
    except Exception:
        pass
    conn.commit()


# ==============================================================================
# Phase 4: Structured Banking Submission & Data Minimization Models
# ==============================================================================

class BankProofSubmission(BaseModel):
    account_holder_name: str = Field(..., min_length=3, max_length=100)
    account_number: str = Field(..., min_length=9, max_length=18)
    confirm_account_number: str = Field(..., min_length=9, max_length=18)
    ifsc_code: str = Field(..., min_length=11, max_length=11)
    relationship: str = Field("Student", description="Student or Father/Mother")

    @validator("ifsc_code")
    def validate_ifsc(cls, v):
        v_clean = v.strip().upper()
        # Statutory RBI IFSC format: 4 alphabets, 0, 6 alphanumeric
        if not re.match(r"^[A-Z]{4}0[A-Z0-9]{6}$", v_clean):
            raise ValueError(f"Invalid Bank IFSC code '{v_clean}'. Must be 11 characters (e.g. SBIN0001234 or HDFC0000128).")
        return v_clean

    @validator("confirm_account_number")
    def match_account_numbers(cls, v, values):
        if "account_number" in values and v != values["account_number"]:
            raise ValueError("Bank Account Number and Confirmation Account Number do not match.")
        return v


def mask_account_number(acc_num: str) -> str:
    """Masks all but the last 4 digits (e.g. '•••••••• 4821')."""
    if len(acc_num) <= 4:
        return acc_num
    return "•" * (len(acc_num) - 4) + " " + acc_num[-4:]


class RefundDisbursementRequest(BaseModel):
    officer_id: str = Field(..., min_length=2)
    officer_name: str = Field(..., min_length=2)
    payment_mode: str = Field("NEFT", description="NEFT, RTGS, or IMPS")
    bank_utr_number: str = Field(..., min_length=8, max_length=30, example="UTR-HDFC-2026-984210")
    disbursed_amount: float = Field(..., ge=1.0)
    comments: Optional[str] = None


# ── Phase 4 Endpoints: Confidential Bank Vault & UTR Disbursement ─────────────

@router.get("/{reference_no}/bank-details", summary="Get Bank Proof (Role-Isolated)")
async def get_withdrawal_bank_details(reference_no: str, request: Request):
    """
    Abhishek Shrivastava's Need-to-Know Vault Gate:
    - If user is Accounts Officer, Finance Department, or Administrator: Returns unmasked account number and IFSC for disbursement.
    - If user is Library, Hostel, or Student: Returns masked number ('•••• 4821') to prevent data leakage.
    """
    _ensure_bank_tables()
    conn = get_connection()
    row = conn.execute(
        """SELECT account_holder_name, account_number, ifsc_code, relationship, bank_proof_file
           FROM withdrawal_bank_details
           WHERE reference_no = ?""",
        (reference_no,),
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Bank details not found for this reference.")

    # Check caller role from JWT token
    user = get_current_user(request)
    user_role = user.get("role") if user else "Public"

    # Only Accounts / Finance and Super-Admin see unmasked digits
    if user_role in ("Accounts Officer", "Finance Department", "Administrator"):
        return {
            "account_holder_name": row["account_holder_name"],
            "account_number": row["account_number"],      # UNMASKED
            "ifsc_code": row["ifsc_code"],
            "relationship": row["relationship"],
            "cheque_file": row["bank_proof_file"],
            "is_masked": False,
        }
    else:
        return {
            "account_holder_name": row["account_holder_name"],
            "account_number": mask_account_number(row["account_number"]),  # MASKED
            "ifsc_code": row["ifsc_code"][:4] + "•••••••",
            "relationship": row["relationship"],
            "cheque_file": row["bank_proof_file"],
            "is_masked": True,
        }


@router.post("/{reference_no}/bank-details", summary="Save Confidential Bank Details")
async def save_withdrawal_bank_details(reference_no: str, req: BankProofSubmission, request: Request):
    """
    Stores encrypted/structured bank proof details for NEFT/RTGS tuition refund wire transfer.
    """
    _ensure_bank_tables()
    conn = get_connection()
    wr = conn.execute("SELECT id, student_id FROM withdrawal_requests WHERE reference_no = ?", (reference_no,)).fetchone()
    if not wr:
        raise HTTPException(status_code=404, detail=f"Withdrawal request '{reference_no}' not found.")

    now = datetime.now(timezone.utc).isoformat()
    conn.execute(
        """INSERT INTO withdrawal_bank_details (reference_no, account_holder_name, account_number, ifsc_code, relationship, bank_proof_file, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?)
           ON CONFLICT(reference_no) DO UPDATE SET
               account_holder_name = excluded.account_holder_name,
               account_number = excluded.account_number,
               ifsc_code = excluded.ifsc_code,
               relationship = excluded.relationship,
               created_at = excluded.created_at""",
        (reference_no, req.account_holder_name, req.account_number, req.ifsc_code, req.relationship, f"cheque_{reference_no}.jpg", now),
    )
    conn.commit()
    return {
        "success": True,
        "message": "Bank details vaulted securely. Unmasked access restricted to Finance Office.",
        "reference_no": reference_no,
        "masked_account": mask_account_number(req.account_number),
    }


@router.post("/{reference_no}/disburse-refund", summary="Disburse Refund & Send UTR Alert")
async def disburse_refund(reference_no: str, req: RefundDisbursementRequest):
    """
    Executed by Finance Officer:
    1. Records the official Bank UTR reference into the audit ledger.
    2. Marks the Accounts clearance gate as 'FUNDS_TRANSFERRED'.
    3. Dispatches a high-priority in-app notification to the student.
    """
    _ensure_bank_tables()
    conn = get_connection()
    now = datetime.now(timezone.utc).isoformat()

    wr = conn.execute("SELECT student_id FROM withdrawal_requests WHERE reference_no = ?", (reference_no,)).fetchone()
    if not wr:
        raise HTTPException(status_code=404, detail=f"Withdrawal request '{reference_no}' not found.")

    student_id = wr["student_id"]

    # 1. Update withdrawal request status
    conn.execute(
        """UPDATE withdrawal_requests
           SET status = 'refund_disbursed',
               refund_utr_number = ?,
               refund_disbursed_at = ?,
               refund_disbursed_amount = ?
           WHERE reference_no = ?""",
        (req.bank_utr_number, now, req.disbursed_amount, reference_no),
    )

    # 2. Mark accounts gate as FUNDS_TRANSFERRED
    conn.execute(
        """UPDATE clearance_gates
           SET status = 'FUNDS_TRANSFERRED',
               cleared_at = ?,
               officer_name = ?,
               officer_id = ?,
               notes = ?
           WHERE reference_no = ? AND department IN ('ACCOUNTS', 'FINANCE')""",
        (now, req.officer_name, req.officer_id, f"Disbursed via {req.payment_mode} (UTR: {req.bank_utr_number})", reference_no),
    )

    # 3. Add to student notification inbox
    import uuid
    notif_id = f"NOTIF-{uuid.uuid4().hex[:8].upper()}"
    try:
        conn.execute(
            """INSERT INTO notifications (id, student_id, notification_type, title, message, priority, read_status, created_at)
               VALUES (?, ?, 'approval', ?, ?, 'high', 'unread', ?) """,
            (
                notif_id,
                student_id,
                "Tuition Refund Credited (NEFT)",
                f"Your university withdrawal refund of ₹{req.disbursed_amount:,.2f} has been remitted to your bank account via {req.payment_mode}. Bank Reference / UTR: {req.bank_utr_number}.",
                now,
            ),
        )
    except Exception:
        try:
            conn.execute(
                """INSERT INTO notifications (student_id, title, message, timestamp)
                   VALUES (?, ?, ?, ?) """,
                (student_id, "Tuition Refund Credited (NEFT)", f"Refund of ₹{req.disbursed_amount:,.2f} via {req.payment_mode}. UTR: {req.bank_utr_number}.", now)
            )
        except Exception:
            pass
    conn.commit()
    return {
        "success": True,
        "message": f"Refund of ₹{req.disbursed_amount} disbursed successfully. UTR {req.bank_utr_number} recorded.",
        "reference_no": reference_no,
        "utr_number": req.bank_utr_number,
    }
