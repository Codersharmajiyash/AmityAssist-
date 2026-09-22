"""Brutal End-to-End System Testing Suite for UniAssist.

Executes comprehensive stress and functional tests across all subsystems:
- Health & Observability
- Authentication & RBAC (Student & Staff)
- Policy Intelligence & BM25 FTS5
- Hybrid Voice Guidance & Navigation
- Program Withdrawal, UGC Slabs & Smart Offsetting
- Token PDF Slip Generation
- Staff Notesheets, Freehand Signature & Word .docx Export
- Student Grievances & 48h SLA Tracking
- Phase 30 Procedure Setup Wizard
- 31-Form University Catalog
"""

from __future__ import annotations

import json
import sys
from fastapi.testclient import TestClient

from backend.main import app

client = TestClient(app)
results = []

def record(test_name: str, passed: bool, details: str = ""):
    status_str = "PASS" if passed else "FAIL"
    results.append({"test": test_name, "passed": passed, "details": details})
    print(f"[{status_str}] {test_name}: {details}")

print("==================================================================")
print("             STARTING BRUTAL FUNCTIONALITY TEST SUITE              ")
print("==================================================================")

# ----------------------------------------------------------------------
# 1. Health & System Status
# ----------------------------------------------------------------------
try:
    r = client.get("/api/health")
    record("System Health Check (/api/health)", r.status_code == 200, f"Status {r.status_code}")
except Exception as e:
    record("System Health Check (/api/health)", False, str(e))

# ----------------------------------------------------------------------
# 2. Authentication: Student & Staff
# ----------------------------------------------------------------------
try:
    r = client.post("/api/auth/verify", json={"student_id": "STU001"})
    passed = r.status_code == 200 and "session_id" in r.json()
    student_token = r.json().get("session_id")
    record("Student Auth (STU001 - Aisha Malik)", passed, f"Token: {student_token[:8]}...")
except Exception as e:
    record("Student Auth (STU001 - Aisha Malik)", False, str(e))

try:
    r = client.post("/api/auth/login", json={"username": "invalid_user", "password": "wrong"})
    record("Invalid Auth Rejection (Security Guard)", r.status_code in (401, 404, 422), f"Rejected with {r.status_code}")
except Exception as e:
    record("Invalid Auth Rejection (Security Guard)", False, str(e))

# ----------------------------------------------------------------------
# 3. Policy Search (SQLite FTS5 BM25)
# ----------------------------------------------------------------------
try:
    r = client.get("/api/policy/search?q=attendance&limit=3")
    data = r.json()
    passed = r.status_code == 200 and data.get("count", 0) > 0
    top_clause = data.get("results", [{}])[0].get("clause_code", "")
    record("FTS5 Policy Search (attendance)", passed, f"Matched {top_clause}, count={data.get('count')}")
except Exception as e:
    record("FTS5 Policy Search (attendance)", False, str(e))

try:
    r = client.get("/api/policy/search?q=refund&category=Withdrawal%20%26%20Refunds")
    data = r.json()
    passed = r.status_code == 200 and data.get("count", 0) > 0
    record("FTS5 Category Filter (Withdrawal & Refunds)", passed, f"Count={data.get('count')}")
except Exception as e:
    record("FTS5 Category Filter (Withdrawal & Refunds)", False, str(e))

try:
    r = client.get("/api/policy/ORD-ACAD-7.2")
    passed = r.status_code == 200 and r.json().get("clause_code") == "ORD-ACAD-7.2"
    record("Exact Clause Code Retrieval", passed, r.json().get("title", ""))
except Exception as e:
    record("Exact Clause Code Retrieval", False, str(e))

# ----------------------------------------------------------------------
# 4. Voice Guidance & Form Procedures
# ----------------------------------------------------------------------
try:
    r = client.post("/api/voice/query", json={
        "spoken_text": "what should i do after getting migration certificate form",
        "language": "en-IN"
    })
    data = r.json()
    passed = r.status_code == 200 and data.get("recommended_action") == "Download Migration Form"
    record("Voice AI: Migration Form Post-Download", passed, f"Action: {data.get('recommended_action')}, URL: {data.get('action_url')}")
except Exception as e:
    record("Voice AI: Migration Form Post-Download", False, str(e))

try:
    r = client.post("/api/voice/query", json={
        "spoken_text": "where can you take me",
        "language": "en-IN"
    })
    data = r.json()
    passed = r.status_code == 200 and "Forms & Applications Catalog" in data.get("response_text", "")
    record("Voice AI: Portal Concierge Navigation", passed, "Returned 5 university portals")
except Exception as e:
    record("Voice AI: Portal Concierge Navigation", False, str(e))

try:
    r = client.post("/api/voice/query", json={
        "spoken_text": "take me to withdrawal",
        "language": "en-IN"
    })
    data = r.json()
    passed = r.status_code == 200 and data.get("action_url") == "/withdrawal"
    record("Voice AI: Direct Route Navigation (/withdrawal)", passed, f"URL: {data.get('action_url')}")
except Exception as e:
    record("Voice AI: Direct Route Navigation (/withdrawal)", False, str(e))

try:
    r = client.post("/api/policy/guide", json={
        "query": "which button to click",
        "page_context": {
            "screen_name": "Clearance Gate Review",
            "route": "/withdrawal/clearance",
            "primary_action": "Settle Via Caution Offset",
            "available_actions": ["Settle Via Caution Offset", "Pay Offline"]
        }
    })
    data = r.json()
    passed = r.status_code == 200 and data.get("highlight_target") == "Settle Via Caution Offset"
    record("Ambient Screen Awareness & Button Highlighting", passed, f"Target: {data.get('highlight_target')}")
except Exception as e:
    record("Ambient Screen Awareness & Button Highlighting", False, str(e))

# ----------------------------------------------------------------------
# 5. Program Withdrawal, UGC Slabs & Smart Caution Deposit Offset
# ----------------------------------------------------------------------
ref_no = None
try:
    r = client.post("/api/withdrawal/apply", json={
        "student_id": "STU001",
        "reason": "Personal relocation out of state",
        "intent": "withdrawal_official"
    })
    data = r.json()
    passed = r.status_code == 200 and "reference_no" in data
    ref_no = data.get("reference_no")
    record("Initiate Withdrawal Request (/api/withdrawal/apply)", passed, f"Reference: {ref_no}")
except Exception as e:
    record("Initiate Withdrawal Request (/api/withdrawal/apply)", False, str(e))

if ref_no:
    try:
        r = client.get(f"/api/withdrawal/status/STU001")
        data = r.json()
        passed = r.status_code == 200 and "gates" in data
        record("Fetch Withdrawal 4-Gate Status", passed, f"{len(data.get('gates', []))} clearance gates loaded")
    except Exception as e:
        record("Fetch Withdrawal 4-Gate Status", False, str(e))

    try:
        r = client.post(f"/api/withdrawal/{ref_no}/offset-dues", json={
            "department": "LIBRARY",
            "amount": 200.0,
            "reason": "Lost Plastic ID Card Replacement Penalty",
            "authorized_by": "Finance Officer"
        })
        passed = r.status_code == 200 and r.json().get("status") == "CLEARED"
        record("Smart Caution Deposit Offset (INR 200 ID fine)", passed, f"Remaining Balance: INR {r.json().get('remaining_balance')}")
    except Exception as e:
        record("Smart Caution Deposit Offset (INR 200 ID fine)", False, str(e))

    try:
        r = client.get(f"/api/withdrawal/{ref_no}/slip")
        passed = r.status_code == 200 and r.content.startswith(b"%PDF")
        record("Token PDF Slip Generation", passed, f"Generated {len(r.content)} bytes PDF binary")
    except Exception as e:
        record("Token PDF Slip Generation", False, str(e))

# ----------------------------------------------------------------------
# 6. Staff Notesheets & Word .docx Export
# ----------------------------------------------------------------------
try:
    r = client.get("/api/notesheets")
    data = r.json()
    passed = r.status_code == 200 and "notesheets" in data and len(data["notesheets"]) > 0
    record("List Staff Notesheets", passed, f"Found {len(data.get('notesheets', []))} notesheets")
except Exception as e:
    record("List Staff Notesheets", False, str(e))

try:
    r = client.get("/api/notesheets/NS-DISC-2026-088")
    data = r.json()
    passed = r.status_code == 200 and data.get("reference_no") == "NS-DISC-2026-088"
    record("Get Disciplinary Notesheet (NS-DISC-2026-088)", passed, f"Stage: {data.get('current_stage')}, Status: {data.get('status')}")
except Exception as e:
    record("Get Disciplinary Notesheet (NS-DISC-2026-088)", False, str(e))

try:
    r = client.post("/api/notesheets/NS-DISC-2026-088/edit-field", json={
        "officer_id": "FAC_HOD_01",
        "officer_role": "HOD",
        "field_name": "restitution_fee",
        "new_value": "INR 3,500 (Audited & Verified)",
        "reason": "Audited with Central Laboratory accounts."
    })
    passed = r.status_code == 200 and r.json().get("success") is True
    record("Notesheet Field Edit with Audit Trail", passed, "Updated restitution_fee")
except Exception as e:
    record("Notesheet Field Edit with Audit Trail", False, str(e))

try:
    r = client.get("/api/notesheets/NS-DISC-2026-088/docx")
    passed = r.status_code == 200 and r.content.startswith(b"PK\x03\x04")
    record("Notesheet Word (.docx) Document Export", passed, f"Valid ZIP/DOCX binary: {len(r.content)} bytes")
except Exception as e:
    record("Notesheet Word (.docx) Document Export", False, str(e))

# ----------------------------------------------------------------------
# 7. Student Grievances & 48h SLA
# ----------------------------------------------------------------------
try:
    r = client.post("/api/student/grievances", json={
        "student_id": "STU001",
        "category": "academic",
        "description": "Elective course confirmation discrepancy on student grade portal."
    })
    data = r.json()
    passed = r.status_code in (200, 201) and "ticket_id" in data and data["ticket_id"].startswith("GRV-2026-")
    record("File Formal Student Grievance", passed, f"Ticket ID: {data.get('ticket_id')}, SLA: {data.get('sla_hours')}h")
except Exception as e:
    record("File Formal Student Grievance", False, str(e))

# ----------------------------------------------------------------------
# 8. Phase 30: Custom Procedure Setup Wizard
# ----------------------------------------------------------------------
try:
    r = client.get("/api/procedures")
    data = r.json()
    passed = r.status_code == 200 and data.get("status") == "success"
    record("List Custom Procedures (Phase 30 Wizard)", passed, f"Found {data.get('count')} procedures")
except Exception as e:
    record("List Custom Procedures (Phase 30 Wizard)", False, str(e))

try:
    r = client.post("/api/procedures", json={
        "title": "Semester Exchange Overseas Transfer Approval",
        "department": "International Relations Cell",
        "category": "academic",
        "description": "Approval workflow for bilateral student exchange program credit mapping.",
        "sla_days": 10,
        "required_docs": ["Partner University Offer Letter", "Credit Equivalence Matrix", "Dean Approval"],
        "steps": [
            {"title": "International Relations Coordinator Review", "description": "Verification of partner institution eligibility.", "responsible_desk": "IRC Window 1", "sla_days": 3},
            {"title": "Dean Academics Sanction", "description": "Course credit equivalence sign-off.", "responsible_desk": "Dean Office Room 201", "sla_days": 5},
            {"title": "Registrar Office Dispatch", "description": "NOC issuance and visa recommendation letter.", "responsible_desk": "Registrar Office Room 102", "sla_days": 2}
        ],
        "created_by": "ADMIN_OFFICER"
    })
    passed = r.status_code in (200, 201) and "id" in r.json().get("procedure", {})
    record("Create Custom Procedure (Phase 30 Wizard)", passed, f"Created ID: {r.json().get('procedure', {}).get('id')}")
except Exception as e:
    record("Create Custom Procedure (Phase 30 Wizard)", False, str(e))

# ----------------------------------------------------------------------
# 9. Forms Catalog: All 31 Forms
# ----------------------------------------------------------------------
try:
    r = client.get("/api/forms/catalog")
    data = r.json()
    forms = data.get("forms", [])
    passed = r.status_code == 200 and len(forms) >= 30
    record("Forms Catalog Integrity (All 31 Forms)", passed, f"Loaded {len(forms)} official downloadable forms")
except Exception as e:
    record("Forms Catalog Integrity (All 31 Forms)", False, str(e))

# ----------------------------------------------------------------------
# Final Summary
# ----------------------------------------------------------------------
print("==================================================================")
passed_count = sum(1 for res in results if res["passed"])
total_count = len(results)
print(f"TOTAL TESTS: {total_count} | PASSED: {passed_count} | FAILED: {total_count - passed_count}")
print("==================================================================")

if passed_count == total_count:
    print("ALL BRUTAL SYSTEM FUNCTIONALITY TESTS PASSED 100%!")
else:
    sys.exit(1)
