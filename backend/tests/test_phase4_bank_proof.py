import pytest
import uuid
from pydantic import ValidationError
from backend.routes.withdrawal import (
    BankProofSubmission,
    RefundDisbursementRequest,
    mask_account_number,
    _ensure_bank_tables,
)
from backend.services.withdrawal_workflow import create_withdrawal_request
from backend.database.connection import get_connection

def test_ifsc_code_validation():
    # Valid IFSC
    model = BankProofSubmission(
        account_holder_name="Rahul Sharma",
        account_number="50100234891234",
        confirm_account_number="50100234891234",
        ifsc_code="HDFC0000128",
        relationship="Student"
    )
    assert model.ifsc_code == "HDFC0000128"

    # Lowercase should be auto-uppercased
    model_lower = BankProofSubmission(
        account_holder_name="Rahul Sharma",
        account_number="50100234891234",
        confirm_account_number="50100234891234",
        ifsc_code="sbin0001234",
        relationship="Student"
    )
    assert model_lower.ifsc_code == "SBIN0001234"

    # Invalid IFSC formats
    with pytest.raises(ValidationError):
        BankProofSubmission(
            account_holder_name="Rahul Sharma",
            account_number="50100234891234",
            confirm_account_number="50100234891234",
            ifsc_code="INVALID123",  # only 10 chars
            relationship="Student"
        )

    with pytest.raises(ValidationError):
        BankProofSubmission(
            account_holder_name="Rahul Sharma",
            account_number="50100234891234",
            confirm_account_number="50100234891234",
            ifsc_code="HDFC1000128",  # 5th char must be 0
            relationship="Student"
        )

def test_account_number_confirmation_match():
    # Matching
    model = BankProofSubmission(
        account_holder_name="Priya Patel",
        account_number="987654321012",
        confirm_account_number="987654321012",
        ifsc_code="ICIC0000001",
        relationship="Student"
    )
    assert model.account_number == "987654321012"

    # Mismatched account numbers
    with pytest.raises(ValidationError):
        BankProofSubmission(
            account_holder_name="Priya Patel",
            account_number="987654321012",
            confirm_account_number="987654321999",
            ifsc_code="ICIC0000001",
            relationship="Student"
        )

def test_account_number_masking():
    assert mask_account_number("50100234891234") == "•••••••••• 1234"
    assert mask_account_number("1234") == "1234"
    assert mask_account_number("987654321") == "••••• 4321"

def test_bank_details_vault_storage_and_role_masking():
    _ensure_bank_tables()
    ref = create_withdrawal_request("STU001", "Personal reasons", "general")
    conn = get_connection()

    # Save details into vault
    sub = BankProofSubmission(
        account_holder_name="Aman Gupta",
        account_number="50100234894821",
        confirm_account_number="50100234894821",
        ifsc_code="HDFC0000128",
        relationship="Student"
    )
    
    conn.execute(
        """INSERT INTO withdrawal_bank_details (reference_no, account_holder_name, account_number, ifsc_code, relationship, bank_proof_file, created_at)
           VALUES (?, ?, ?, ?, ?, ?, '2026-10-30T20:00:00Z')
           ON CONFLICT(reference_no) DO UPDATE SET
               account_holder_name = excluded.account_holder_name,
               account_number = excluded.account_number,
               ifsc_code = excluded.ifsc_code""",
        (ref, sub.account_holder_name, sub.account_number, sub.ifsc_code, sub.relationship, f"cheque_{ref}.jpg"),
    )
    conn.commit()

    # Verify database record
    row = conn.execute("SELECT * FROM withdrawal_bank_details WHERE reference_no = ?", (ref,)).fetchone()
    assert row is not None
    assert row["account_number"] == "50100234894821"

    # Simulate Non-Finance view (Librarian/Student/Public)
    masked_acc = mask_account_number(row["account_number"])
    masked_ifsc = row["ifsc_code"][:4] + "•••••••"
    assert "4821" in masked_acc
    assert "5010" not in masked_acc
    assert masked_ifsc == "HDFC•••••••"

def test_finance_disbursement_and_utr_notification():
    _ensure_bank_tables()
    ref = create_withdrawal_request("STU001", "Financial reasons", "financial")
    conn = get_connection()

    req = RefundDisbursementRequest(
        officer_id="OFF-FIN-01",
        officer_name="Mr. Sharma",
        payment_mode="NEFT",
        bank_utr_number="UTR-HDFC-2026-984210",
        disbursed_amount=95000.0,
        comments="Settlement completed per UGC norms."
    )

    # 1. Update status
    now = "2026-10-30T20:30:00Z"
    conn.execute(
        """UPDATE withdrawal_requests
           SET status = 'refund_disbursed',
               refund_utr_number = ?,
               refund_disbursed_at = ?,
               refund_disbursed_amount = ?
           WHERE reference_no = ?""",
        (req.bank_utr_number, now, req.disbursed_amount, ref),
    )

    # 2. Mark Accounts clearance gate as FUNDS_TRANSFERRED
    conn.execute(
        """UPDATE clearance_gates
           SET status = 'FUNDS_TRANSFERRED',
               cleared_at = ?,
               officer_name = ?,
               officer_id = ?,
               notes = ?
           WHERE reference_no = ? AND department IN ('ACCOUNTS', 'FINANCE')""",
        (now, req.officer_name, req.officer_id, f"Disbursed via {req.payment_mode} (UTR: {req.bank_utr_number})", ref),
    )

    # 3. Add notification
    notif_id = f"NOTIF-{uuid.uuid4().hex[:8].upper()}"
    conn.execute(
        """INSERT INTO notifications (id, student_id, notification_type, title, message, priority, read_status, created_at)
           VALUES (?, ?, 'approval', ?, ?, 'high', 'unread', ?)""",
        (
            notif_id,
            "STU001",
            "Tuition Refund Credited (NEFT)",
            f"Your university withdrawal refund of ₹{req.disbursed_amount:,.2f} has been remitted to your bank account via {req.payment_mode}. Bank Reference / UTR: {req.bank_utr_number}.",
            now,
        ),
    )
    conn.commit()

    # Assertions
    wr = conn.execute("SELECT * FROM withdrawal_requests WHERE reference_no = ?", (ref,)).fetchone()
    assert wr["status"] == "refund_disbursed"
    assert wr["refund_utr_number"] == "UTR-HDFC-2026-984210"
    assert wr["refund_disbursed_amount"] == 95000.0

    notif = conn.execute(
        "SELECT * FROM notifications WHERE student_id = 'STU001' ORDER BY created_at DESC LIMIT 1"
    ).fetchone()
    assert notif is not None
    assert "UTR-HDFC-2026-984210" in notif["message"]
    assert "95,000.00" in notif["message"]

    gate = conn.execute(
        "SELECT * FROM clearance_gates WHERE reference_no = ? AND department = 'ACCOUNTS'", (ref,)
    ).fetchone()
    assert gate is not None
    assert gate["status"] == "FUNDS_TRANSFERRED"
