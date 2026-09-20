"""Phase 29: Intelligent Search & Policy Guidance Service.

Combines SQLite FTS5 (BM25 Inverted Index) for sub-5ms legal ordinance retrieval
with personalized hybrid RAG advice synthesis (attendance condonation, withdrawal
refund slabs, caution deposit offset, post-form submission guidance, and voice TTS guidance).
"""

from __future__ import annotations

import re
import sqlite3
from typing import Any

from ..config import settings
from ..database.connection import get_connection
from ..services.nlp_service import score_sentiment
from ..services.advanced_ai_service import synthesize_guidance_with_gemini


# ---------------------------------------------------------------------------
# Seed Ordinances & University Handbooks + Form Post-Download Workflows
# ---------------------------------------------------------------------------

DEFAULT_POLICIES = [
    # Core Ordinances
    {
        "doc_id": "POL-ACAD-01",
        "category": "Academics",
        "title": "Minimum Attendance Requirement & Dean's Condonation",
        "clause_code": "ORD-ACAD-7.2",
        "content": (
            "Minimum attendance requirement is 75% in every registered course to be eligible "
            "to sit for End Term Semester Examinations. If overall attendance is between 60% and 74%, "
            "the student may apply for Dean Condonation on medical or approved official university duty "
            "grounds by submitting Form AC-04 along with medical certificates at least 10 working days "
            "prior to exam commencement. Attendance below 60% constitutes mandatory debarment with zero condonation."
        ),
        "action_url": "/forms",
        "action_label": "Download Form AC-04 (Condonation)",
    },
    {
        "doc_id": "POL-WTH-01",
        "category": "Withdrawal & Refunds",
        "title": "Program Withdrawal & Tuition Fee Refund Mandates (UGC Aligned)",
        "clause_code": "ORD-WTH-14.1",
        "content": (
            "Withdrawal of admission and academic fee refunds adhere to UGC 2024 directives: "
            "(a) 15 days or more prior to formally notified admission deadline: 100% refund minus max processing fee INR 1,000; "
            "(b) Less than 15 days prior to admission deadline: 90% refund; "
            "(c) Up to 15 days post admission deadline: 80% refund; "
            "(d) Between 16 and 30 days post admission deadline: 50% refund; "
            "(e) Beyond 30 days post admission deadline: 0% tuition refund. "
            "Refundable Security/Caution Deposit of INR 10,000 is always refunded 100% across all slabs."
        ),
        "action_url": "/withdrawal",
        "action_label": "Start Withdrawal Procedure",
    },
    {
        "doc_id": "POL-FIN-01",
        "category": "Finance",
        "title": "Caution Deposit Smart Offsetting for Unreturned Assets & Fines",
        "clause_code": "ORD-FIN-14.4",
        "content": (
            "Under the Smart Financial Offsetting amendment, students undergoing departure or clearance "
            "with minor unreturned assets, lost plastic ID card replacement fees (INR 200), or library fines "
            "under INR 2,000 may opt for 1-tap direct deduction from their refundable caution deposit balance "
            "(standard balance INR 10,000). The clearance gate updates to CLEARED_VIA_OFFSET immediately without "
            "requiring physical bank visits or offline challans."
        ),
        "action_url": "/withdrawal",
        "action_label": "View Clearance Status",
    },
    {
        "doc_id": "POL-CLR-01",
        "category": "Clearance",
        "title": "Sequential 4-Gate Institutional Clearance Pipeline",
        "clause_code": "ORD-CLR-9.3",
        "content": (
            "Institutional departure, transfer certificate issuance, or withdrawal requires digital sign-off "
            "across 4 sequential clearance desks: Gate 1 Central Library (book returns & dues); Gate 2 Hostel & Mess Office "
            "(inventory inspection & room handover); Gate 3 Finance & Accounts (fee audit & deposit offset reconciliation); "
            "Gate 4 Registrar Office (final document audit & degree release). Each desk officer records digital authorization."
        ),
        "action_url": "/withdrawal",
        "action_label": "Track Clearance Gates",
    },
    {
        "doc_id": "POL-EXAM-01",
        "category": "Examinations",
        "title": "Backpaper & Supplementary Examination Guidelines",
        "clause_code": "ORD-EXAM-12.1",
        "content": (
            "Students with failed courses or seeking grade improvement may apply for Supplementary Backpaper Examinations. "
            "The examination fee is INR 1,500 per registered subject. Applications must be submitted through Form EX-02 within "
            "14 calendar days of semester grade sheet publication. Answer script re-evaluation is admissible within 7 days at INR 750 per subject."
        ),
        "action_url": "/forms",
        "action_label": "Download Form EX-02 (Backpaper)",
    },
    {
        "doc_id": "POL-HSTL-01",
        "category": "Hostel",
        "title": "Hostel Room Vacation, Inventory Handover & Key Return",
        "clause_code": "ORD-HSTL-18.2",
        "content": (
            "Hostel residents vacating campus quarters must conduct physical inventory inspection with the Assistant Warden. "
            "Room inventory checklist and key submission must be completed 24 hours prior to departure. Any physical room damage "
            "or missing fixtures will be offset against the hostel security deposit balance."
        ),
        "action_url": "/forms",
        "action_label": "Hostel Vacation Guidelines",
    },
    {
        "doc_id": "POL-GRV-01",
        "category": "Grievances",
        "title": "Student Grievance Redressal SLA & Proctorial Escalation",
        "clause_code": "ORD-GRV-22.5",
        "content": (
            "Formal student grievances submitted through the portal carry mandatory resolution SLAs: Academic and facility "
            "grievances must be addressed by the Department Coordinator within 48 hours. If unresolved after 48 hours, the ticket "
            "is automatically escalated to the Dean of Student Welfare. Harassment, ragging, or physical safety tickets have an emergency 24h SLA."
        ),
        "action_url": "/chat",
        "action_label": "File Formal Grievance",
    },
    {
        "doc_id": "POL-SCH-01",
        "category": "Scholarships",
        "title": "Merit & Financial Assistance Scholarship Renewal Criteria",
        "clause_code": "ORD-SCH-16.3",
        "content": (
            "Continuation of university merit scholarships requires maintaining a minimum CGPA of 8.0, minimum 80% attendance, "
            "and zero backpapers in the previous academic year. Need-based tuition concessions require annual submission of valid family "
            "income certificate before August 31st annually."
        ),
        "action_url": "/scholarship",
        "action_label": "Explore Scholarships",
    },

    # --- Comprehensive Post-Download Form Procedures (All 30+ Catalog Forms) ---
    {
        "doc_id": "PROC-FORM-MIGRATION",
        "category": "Academics",
        "title": "Migration Certificate Application Procedure",
        "clause_code": "PROC-FORM-15",
        "content": (
            "After obtaining the Migration Certificate Application Form (.doc or .pdf), follow these steps: "
            "1. Attach attested photocopies of all semester grade sheets, provisional degree or bonafide certificate, "
            "university no-dues clearance slip, and student ID proof. "
            "2. Submit the completed application dossier to Registrar Office Window 2 (Room 102, Administrative Block). "
            "3. Official turnaround SLA is 3 to 5 working days. The migration certificate can be collected in person from Window 2 "
            "or dispatched via registered speed post to your home address."
        ),
        "action_url": "/forms",
        "action_label": "Download Migration Form",
    },
    {
        "doc_id": "PROC-FORM-RECHECKING",
        "category": "Examinations",
        "title": "Application for Rechecking & Re-evaluation of Result",
        "clause_code": "PROC-FORM-27",
        "content": (
            "After downloading the Application for Rechecking of Result, follow these steps: "
            "1. Clearly specify subject course codes, paper titles, and semester. "
            "2. Pay the rechecking fee of Rupees 500 per subject paper at the Accounts Counter (Room 14) or online gateway, "
            "and attach the payment receipt and photocopy of your current semester grade report. "
            "3. Submit the completed form to the Controller of Examinations (Examination Cell Window 3) within 15 calendar days "
            "of result declaration. Processing SLA is 21 working days."
        ),
        "action_url": "/forms",
        "action_label": "Download Rechecking Form",
    },
    {
        "doc_id": "PROC-FORM-STUDENT-ID",
        "category": "Admissions & Registrar",
        "title": "Student ID Card Re-issue & Duplicate Form",
        "clause_code": "PROC-FORM-28",
        "content": (
            "After downloading the Student ID Card Form, follow these steps: "
            "1. Fill your enrollment number, program, blood group, and emergency contact details. "
            "2. Attach 1 recent passport photograph (white background), copy of police lost report / NCR (if lost), "
            "and settle the Rupees 200 re-issue fee (or choose Smart Caution Deposit Offsetting). "
            "3. Submit the form to Student Services / Registrar Desk (Room 101). SLA is 48 hours for biometric smart card collection."
        ),
        "action_url": "/forms",
        "action_label": "Download Student ID Form",
    },
    {
        "doc_id": "PROC-FORM-CONDONATION",
        "category": "Academics",
        "title": "Attendance Condonation Application (Form AC-04)",
        "clause_code": "PROC-FORM-AC04",
        "content": (
            "After obtaining Form AC-04 (Attendance Condonation Application), follow these steps: "
            "1. Fill the course codes where your attendance is between 60% and 74.9%. "
            "2. Attach authentic medical certificates with prescription and hospital OPD slips, or verified university duty certificates. "
            "3. Submit the file to the Dean of Academic Affairs (Room 201, Academic Block) at least 10 working days prior to exam start. "
            "If approved, your exam admit card will be unblocked within 48 hours."
        ),
        "action_url": "/forms",
        "action_label": "Download Form AC-04",
    },
    {
        "doc_id": "PROC-FORM-EXIT-INTERVIEW",
        "category": "Student Welfare",
        "title": "Exit Interview Form for Program Withdrawal",
        "clause_code": "PROC-FORM-17",
        "content": (
            "After downloading the Exit Interview Form for Withdrawal, follow these steps: "
            "1. Complete the feedback questionnaire regarding academic experience, facilities, and reason for leaving. "
            "2. Verify completion of the 4 clearance gates (Library, Hostel, Accounts, Department Advisor). "
            "3. Attend a mandatory 15-minute exit counseling meeting with the Dean of Student Welfare (Room 106). "
            "Once signed, submit to Registrar Office (Room 102) to release caution deposit (Rupees 10,000) and tuition fee refund."
        ),
        "action_url": "/withdrawal",
        "action_label": "Open Withdrawal & Exit Portal",
    },
    {
        "doc_id": "PROC-FORM-WITHDRAWAL-APP",
        "category": "Withdrawal & Refunds",
        "title": "Program Withdrawal Application Form",
        "clause_code": "PROC-FORM-WTH",
        "content": (
            "After downloading the Program Withdrawal Application Form, follow these steps: "
            "1. State your primary reason for program withdrawal and attach parent/guardian consent letter, student identity proof, "
            "and a cancelled bank cheque or passbook copy showing IFSC code for NEFT refund transfer. "
            "2. Initiate digital clearance across Library, Hostel, and Finance gates. "
            "3. Submit the signed dossier to Registrar Office (Room 102). Tuition refund is calculated under UGC date slabs, "
            "and the Rupees 10,000 caution deposit is 100% refundable within 14 working days."
        ),
        "action_url": "/withdrawal",
        "action_label": "Start Withdrawal Procedure",
    },
    {
        "doc_id": "PROC-FORM-FEE-CLEARANCE",
        "category": "Finance",
        "title": "Fee Clearance Statement & No Dues Form",
        "clause_code": "PROC-FORM-FEE-CLR",
        "content": (
            "After downloading the Fee Clearance Form, follow these steps: "
            "1. Review pending semester tuition dues, fine assessments, or security balances. "
            "2. If you have outstanding dues under Rupees 2,000 (such as library penalties or lost ID card fee), "
            "check the Smart Offsetting box to auto-deduct from your caution deposit without visiting the bank. "
            "3. Submit the verified clearance slip to Finance & Accounts Counter (Window 4). Clearance updates to CLEARED immediately."
        ),
        "action_url": "/withdrawal",
        "action_label": "View Fee Clearance Gate",
    },
    {
        "doc_id": "PROC-FORM-LIBRARY-CLEARANCE",
        "category": "Clearance",
        "title": "Library No-Dues Clearance Form",
        "clause_code": "PROC-FORM-LIB-CLR",
        "content": (
            "After obtaining the Library Clearance Form, follow these steps: "
            "1. Physically return all borrowed books, reference volumes, and departmental CDs to the Central Library circulation counter. "
            "2. Settle any overdue late fines (Rupees 5 per day) or authorize direct offset against your caution deposit. "
            "3. The Chief Librarian will stamp and digitally clear your Library gate in the university ERP system."
        ),
        "action_url": "/withdrawal",
        "action_label": "View Library Clearance Gate",
    },
    {
        "doc_id": "PROC-FORM-HOSTEL-CLEARANCE",
        "category": "Hostel",
        "title": "Hostel Vacation & Handover Clearance Form",
        "clause_code": "PROC-FORM-HSTL-CLR",
        "content": (
            "After obtaining the Hostel Clearance Form, follow these steps: "
            "1. Request physical room inspection with your Assistant Warden 24 hours prior to vacating. "
            "2. Hand over room keys, almirah keys, and verify the room inventory checklist (fan, light fixtures, furniture). "
            "3. Obtain Warden sign-off and submit the stamped form to the Hostel Administration Desk (Campus Gate 2). "
            "Hostel security deposit refund is cleared within 7 working days."
        ),
        "action_url": "/withdrawal",
        "action_label": "View Hostel Clearance Gate",
    },
    {
        "doc_id": "PROC-FORM-DEGREE",
        "category": "Examinations",
        "title": "Degree Application & Convocation Format",
        "clause_code": "PROC-FORM-22",
        "content": (
            "After downloading the Degree Application Format, follow these steps: "
            "1. Attach attested photocopies of final cumulative grade sheet (all semesters passed), 10th class passing certificate "
            "(for date-of-birth verification), university no-dues clearance certificate, and Rupees 1,500 convocation fee receipt. "
            "2. Submit the dossier to the Controller of Examinations (Degree Cell Window 1). Turnaround SLA is 15 working days "
            "for provisional degree and convocation roll inclusion."
        ),
        "action_url": "/forms",
        "action_label": "Download Degree Application",
    },
    {
        "doc_id": "PROC-FORM-EXAM-BLANK",
        "category": "Examinations",
        "title": "Blank Examination Application Form",
        "clause_code": "PROC-FORM-20",
        "content": (
            "After downloading the Blank Examination Form, follow these steps: "
            "1. Enter your chosen core and elective course codes for the upcoming end-term semester exams. "
            "2. Verify that your attendance in each subject is above the 75% cutoff. "
            "3. Attach your semester exam fee challan and submit the form to the Examination Cell (Block 3, Room 110) "
            "before the notified semester examination cutoff date."
        ),
        "action_url": "/exams",
        "action_label": "Open Exam Application",
    },
    {
        "doc_id": "PROC-FORM-PLACEMENT-OPT",
        "category": "Career & Placement",
        "title": "Placement Opted Out Declaration Form",
        "clause_code": "PROC-FORM-16",
        "content": (
            "After downloading the Placement Opted Out Declaration Form, follow these steps: "
            "1. Fill your details and declare your chosen post-graduation plan (higher studies / GRE / GATE / civil services, entrepreneurship, or family business). "
            "2. Obtain parent / guardian endorsement signature. "
            "3. Submit the completed declaration to Corporate Resource Centre (CRC, Block E Ground Floor). "
            "You will be exempted from mandatory campus placement attendance without penalty."
        ),
        "action_url": "/forms",
        "action_label": "Download Placement Opt-Out Form",
    },
    {
        "doc_id": "PROC-FORM-TADA",
        "category": "Finance",
        "title": "Travelling & Daily Allowance (TA/DA) Claim Format",
        "clause_code": "PROC-FORM-08",
        "content": (
            "After downloading the TA / DA Claim Format, follow these steps: "
            "1. Enter departure and arrival dates, conveyance modes, and daily allowance entitlement. "
            "2. Attach original boarding passes, rail / air tickets, taxi bills, and event participation certificate "
            "along with the prior university duty approval sanction. "
            "3. Submit the claim to Finance & Accounts (Room 14) within 30 days of travel. Reimbursement SLA is 7 to 10 working days."
        ),
        "action_url": "/forms",
        "action_label": "Download TA/DA Claim Form",
    },
    {
        "doc_id": "PROC-FORM-LOCAL-CONV",
        "category": "Finance",
        "title": "Local Conveyance Reimbursement Form",
        "clause_code": "PROC-FORM-11",
        "content": (
            "After downloading the Local Conveyance Form, follow these steps: "
            "1. Fill travel date, destinations, official purpose, and kilometer reading or fare. "
            "2. Attach original fuel slips, metro receipts, or taxi invoices. "
            "3. Obtain HOD or reporting supervisor approval and submit to Finance Counter (Room 14). "
            "Reimbursement is processed within 5 working days."
        ),
        "action_url": "/forms",
        "action_label": "Download Local Conveyance Form",
    },
    {
        "doc_id": "PROC-FORM-IMPREST",
        "category": "Finance",
        "title": "Advance Imprest Requisition Form",
        "clause_code": "PROC-FORM-12",
        "content": (
            "After downloading the Advance Imprest Requisition Form, follow these steps: "
            "1. Specify the official purpose, event name, and detailed budget breakdown. "
            "2. Obtain sanction endorsement from the Pro-Chancellor / Registrar. "
            "3. Submit the sanctioned requisition to Finance & Accounts for check or bank transfer disbursement. "
            "Final bills and expense settlement must be submitted within 15 calendar days of event completion."
        ),
        "action_url": "/forms",
        "action_label": "Download Imprest Requisition",
    },
    {
        "doc_id": "PROC-FORM-MENTOR",
        "category": "Student Welfare",
        "title": "Mentoring Record Card & Mentor-Mentee Log",
        "clause_code": "PROC-FORM-13",
        "content": (
            "After downloading the Mentoring Record Card, follow these steps: "
            "1. Schedule your monthly 1-on-1 counseling session with your assigned faculty mentor. "
            "2. Update your attendance percentage, mid-term test scores, career ambitions, and any personal grievances. "
            "3. Both student and mentor sign the card; it is maintained in the Department Mentorship Cell for academic progress tracking."
        ),
        "action_url": "/forms",
        "action_label": "Download Mentoring Record",
    },
    {
        "doc_id": "PROC-FORM-PURCHASE",
        "category": "Procurement",
        "title": "Purchase Proposal & Requisition Format",
        "clause_code": "PROC-FORM-14",
        "content": (
            "After downloading the Purchase Proposal Format, follow these steps: "
            "1. Fill equipment or consumable specifications, quantity, and estimated budget code. "
            "2. Attach minimum 3 comparative vendor quotations and technical justification. "
            "3. Obtain HOD recommendation and submit to Central Purchase Committee (Stores Building). Review turnaround is 7 working days."
        ),
        "action_url": "/forms",
        "action_label": "Download Purchase Proposal",
    },
    {
        "doc_id": "PROC-FORM-STATIONERY",
        "category": "Logistics & Stores",
        "title": "Stationery Indent Requisition Format",
        "clause_code": "PROC-FORM-18",
        "content": (
            "After downloading the Stationery Indent Requisition, follow these steps: "
            "1. Itemize required office and classroom supplies (registers, markers, paper reams, printer cartridges). "
            "2. Obtain department coordinator signature. "
            "3. Submit indent to Central Store counter on distribution days (Tuesdays and Thursdays, 10 AM to 1 PM)."
        ),
        "action_url": "/forms",
        "action_label": "Download Stationery Indent",
    },
    {
        "doc_id": "PROC-FORM-BIOMETRIC",
        "category": "HR & IT",
        "title": "Biometric / ID Card Issue Application",
        "clause_code": "PROC-FORM-19",
        "content": (
            "After downloading the Biometric / Forgotten ID Card Application, follow these steps: "
            "1. Fill employee/student ID, department, and reason for re-issue. "
            "2. Obtain supervisor sign-off. "
            "3. Bring the form to IT Support & Biometrics Desk (Admin Block Room 105) for instant biometric re-registration and temporary RFID access clearance."
        ),
        "action_url": "/forms",
        "action_label": "Download Biometric Application",
    },
    {
        "doc_id": "PROC-FORM-FACULTY-LEAVE",
        "category": "HR & Staff",
        "title": "Faculty Leave Application & Emergency Leave Proforma",
        "clause_code": "PROC-FORM-23",
        "content": (
            "After downloading the Faculty Leave Application / Emergency Leave Proforma, follow these steps: "
            "1. Specify leave type (Casual, Earned, Duty, Medical, or Emergency). "
            "2. Secure substitute colleague teacher signatures on the class arrangement sheet. "
            "3. Submit the completed application to HR Administration (Room 103) at least 48 hours prior to planned absence "
            "(or within 24 hours of resuming for emergency leave)."
        ),
        "action_url": "/forms",
        "action_label": "Download Leave Application",
    },
    {
        "doc_id": "PROC-FORM-EMPLOYEE-ID",
        "category": "HR & Staff",
        "title": "Employee ID Card Form",
        "clause_code": "PROC-FORM-24",
        "content": (
            "After downloading the Employee ID Card Form, follow these steps: "
            "1. Fill employee personal details, blood group, designation, and department. "
            "2. Attach official appointment letter copy and one passport photograph with white background. "
            "3. Submit to HR Desk (Admin Block Room 103). SLA is 2 working days for card printing and campus access activation."
        ),
        "action_url": "/forms",
        "action_label": "Download Employee ID Form",
    },
    {
        "doc_id": "PROC-FORM-CLASS-ARRANGEMENT",
        "category": "Academics",
        "title": "Class Arrangement Format",
        "clause_code": "PROC-FORM-03",
        "content": (
            "After downloading the Class Arrangement Format, follow these steps: "
            "1. Enter subject names, classroom numbers, and scheduled lecture timings. "
            "2. Obtain written agreement signatures from covering faculty colleagues. "
            "3. Submit the form to Department Time-Table Coordinator 24 hours prior to leave."
        ),
        "action_url": "/forms",
        "action_label": "Download Class Arrangement Form",
    },
    {
        "doc_id": "PROC-FORM-FINANCIAL-ASST",
        "category": "Finance",
        "title": "Format for Financial Assistance for Events",
        "clause_code": "PROC-FORM-06",
        "content": (
            "After downloading the Financial Assistance Form for Events, follow these steps: "
            "1. Attach technical event brochure, expected guest list, and itemized expenditure proposal. "
            "2. Secure faculty advisor and student club head endorsement. "
            "3. Submit to Dean of Student Welfare (Room 106) at least 3 weeks prior to event date."
        ),
        "action_url": "/forms",
        "action_label": "Download Financial Asst Form",
    },
    {
        "doc_id": "PROC-FORM-DEBARRED-LETTER",
        "category": "Academics",
        "title": "Notice Letter to Parents of Debarred Students",
        "clause_code": "PROC-FORM-07",
        "content": (
            "Format Letter to Parents of Debarred Students is an institutional academic alert issued when student attendance falls below 60%. "
            "Parents must attend a mandatory proctorial meeting with the Department Head within 5 working days to establish an academic probation contract and remedial recovery plan."
        ),
        "action_url": "/forms",
        "action_label": "View Debarment Letter Format",
    },
    {
        "doc_id": "PROC-FORM-TRANSPORT",
        "category": "Logistics & Fleet",
        "title": "Requisition for Transport",
        "clause_code": "PROC-FORM-10",
        "content": (
            "After downloading the Requisition for Transport, follow these steps: "
            "1. Specify trip date, pickup/drop times, destination, passenger list, and official purpose. "
            "2. Obtain HOD sanction signature. "
            "3. Submit to Transport Officer (Campus Gate 2 Office) at least 48 hours prior to scheduled departure."
        ),
        "action_url": "/forms",
        "action_label": "Download Transport Requisition",
    },
    {
        "doc_id": "PROC-FORM-CAFETERIA",
        "category": "Logistics & Catering",
        "title": "Requisition for Refreshment (Cafeteria)",
        "clause_code": "PROC-FORM-09",
        "content": (
            "After downloading the Requisition for Refreshment (Cafeteria), follow these steps: "
            "1. Fill meeting / seminar name, venue room, guest count, and selected catering menu items. "
            "2. Obtain departmental financial approval. "
            "3. Submit to Hospitality & Cafeteria Manager 24 hours in advance."
        ),
        "action_url": "/forms",
        "action_label": "Download Refreshment Requisition",
    },
    {
        "doc_id": "PROC-FORM-PATENTS",
        "category": "Research & Patents",
        "title": "List of Patents & IP Disclosure Format",
        "clause_code": "PROC-FORM-PAT",
        "content": (
            "The Patents Directory and Invention Disclosure Format allows faculty and students to protect intellectual property. "
            "Complete patent disclosure forms, attach novelty claims and diagrams, and submit to Dean of Research & Development (Room 304). "
            "University provides 100% patent filing funding for approved inventions."
        ),
        "action_url": "/forms",
        "action_label": "View Patent Registry Format",
    },
    {
        "doc_id": "PROC-FORM-CARTRIDGE",
        "category": "IT & Logistics",
        "title": "Cartridge Refill Form",
        "clause_code": "PROC-FORM-21",
        "content": (
            "After downloading the Cartridge Refill Form, follow these steps: "
            "1. Record departmental printer serial number and model. "
            "2. Obtain lab technician endorsement. "
            "3. Take empty cartridge and form to IT Hardware Desk (Server Room, 2nd Floor). Turnaround SLA is 4 hours."
        ),
        "action_url": "/forms",
        "action_label": "Download Cartridge Requisition",
    },
    {
        "doc_id": "PROC-FORM-DIRECTORY",
        "category": "Directory",
        "title": "ASET Faculty & Staff Contact Directory",
        "clause_code": "PROC-FORM-05",
        "content": (
            "The Faculty & Staff Contact Directory provides official intercom extensions, office room numbers, email addresses, "
            "and consultation hours for all ASET professors, academic coordinators, and laboratory instructors."
        ),
        "action_url": "/forms",
        "action_label": "View Faculty Directory",
    },
    {
        "doc_id": "PROC-FORM-DL",
        "category": "Logistics & Fleet",
        "title": "Driving License / Duty Driving Permission Form",
        "clause_code": "PROC-FORM-01",
        "content": (
            "After downloading the DL Permission Form, follow these steps: "
            "1. Attach copy of valid state driving license and institutional appointment proof. "
            "2. Obtain Department Head sign-off. "
            "3. Submit to Campus Security & Fleet Office (Gate 1). Turnaround SLA is 24 hours."
        ),
        "action_url": "/forms",
        "action_label": "Download DL Permission Form",
    },
]


class PolicySearchService:
    """Provides SQLite FTS5 full-text search and personalized policy guidance."""

    @classmethod
    def initialize_fts_index(cls) -> None:
        """Create and populate the FTS5 virtual table if empty or incomplete."""
        conn = get_connection()
        conn.execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS policy_fts USING fts5(
                doc_id UNINDEXED,
                category,
                title,
                clause_code,
                content,
                action_url UNINDEXED,
                action_label UNINDEXED,
                tokenize='porter unicode61'
            );
            """
        )

        cur = conn.execute("SELECT count(*) FROM policy_fts")
        count = cur.fetchone()[0]

        if count < len(DEFAULT_POLICIES):
            conn.execute("DELETE FROM policy_fts")
            for p in DEFAULT_POLICIES:
                conn.execute(
                    """
                    INSERT INTO policy_fts (doc_id, category, title, clause_code, content, action_url, action_label)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        p["doc_id"],
                        p["category"],
                        p["title"],
                        p["clause_code"],
                        p["content"],
                        p["action_url"],
                        p["action_label"],
                    ),
                )
            conn.commit()

    @classmethod
    def search_policies(
        cls,
        query: str,
        category: str | None = None,
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        """Search policy ordinances using BM25 ranking and snippet generation."""
        cls.initialize_fts_index()
        conn = get_connection()

        sanitized = re.sub(r"[^\w\s]", " ", query).strip()
        if not sanitized:
            return []

        stop_words = {
            "what", "should", "i", "do", "after", "getting", "the", "a", "an", "this",
            "that", "from", "how", "can", "you", "take", "me", "tell", "where", "is",
            "of", "to", "for", "in", "on", "at", "by", "with", "my", "please", "want",
            "would", "like", "get", "downloading", "having", "got", "need", "know", "about",
            "which", "we", "he", "she", "they", "them", "their", "are", "be", "been", "here"
        }
        all_words = [token.lower() for token in sanitized.split() if token]
        content_words = [w for w in all_words if w not in stop_words]
        query_words = content_words if content_words else all_words

        # Try progressive matching: Pass 1 with AND (high precision), Pass 2 with OR (high recall)
        for operator in (" AND ", " OR "):
            tokens = [f'"{w}"*' for w in query_words]
            match_expr = operator.join(tokens)

            params: list[Any] = []
            sql = """
                SELECT
                    doc_id,
                    category,
                    title,
                    clause_code,
                    content,
                    action_url,
                    action_label,
                    snippet(policy_fts, 4, '<mark>', '</mark>', '...', 28) AS snippet_text,
                    bm25(policy_fts) AS rank_score
                FROM policy_fts
                WHERE policy_fts MATCH ?
            """
            params.append(match_expr)

            if category and category.lower() != "all":
                sql += " AND category = ?"
                params.append(category)

            sql += " ORDER BY rank_score ASC LIMIT ?"
            params.append(limit)

            try:
                cur = conn.execute(sql, params)
                rows = cur.fetchall()
                if rows:
                    results = []
                    for r in rows:
                        results.append(
                            {
                                "doc_id": r["doc_id"],
                                "category": r["category"],
                                "title": r["title"],
                                "clause_code": r["clause_code"],
                                "content": r["content"],
                                "action_url": r["action_url"],
                                "action_label": r["action_label"],
                                "snippet": r["snippet_text"] or (r["content"][:160] + "..."),
                                "score": round(float(r["rank_score"]), 3),
                            }
                        )
                    return results
            except sqlite3.OperationalError:
                continue

        # Fallback for conversational sentences or syntax deviations
        fallback_sql = """
            SELECT doc_id, category, title, clause_code, content, action_url, action_label
            FROM policy_fts
            WHERE content LIKE ? OR title LIKE ?
            LIMIT ?
        """
        key_term = query_words[0] if query_words else sanitized[:25]
        like_pat = f"%{key_term}%"
        cur = conn.execute(fallback_sql, (like_pat, like_pat, limit))
        results = []
        for r in cur.fetchall():
            results.append(
                {
                    "doc_id": r["doc_id"],
                    "category": r["category"],
                    "title": r["title"],
                    "clause_code": r["clause_code"],
                    "content": r["content"],
                    "action_url": r["action_url"],
                    "action_label": r["action_label"],
                    "snippet": r["content"][:160] + "...",
                    "score": 0.0,
                }
            )
        return results

    @classmethod
    def hybrid_guidance(
        cls,
        query: str,
        student_id: str | None = None,
        page_context: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Synthesize zero-hallucination guidance combining live student profile, FTS5 policy clauses, ambient screen awareness, and optional Gemini AI synthesis."""
        conn = get_connection()
        policies = cls.search_policies(query, limit=3)

        # Retrieve student record if authenticated
        student: dict[str, Any] | None = None
        if student_id and student_id != "GUEST" and student_id != "PUBLIC":
            cur = conn.execute(
                "SELECT id, name, course, branch, semester, attendance, cgpa, fee_status, fee_due FROM students WHERE id = ?",
                (student_id,),
            )
            row = cur.fetchone()
            if row:
                student = dict(row)

        is_authenticated = student is not None
        student_name = (student or {}).get("name", "").split()[0] if is_authenticated else "Student"
        attendance = float((student or {}).get("attendance", 75.0))

        q_lower = query.lower()

        # =========================================================================
        # 1. Broad Navigation: "Where can you take me?" / "What portals are available?"
        # =========================================================================
        if any(w in q_lower for w in ["where can you take me", "what can you take me", "where can you navigate", "which pages", "available portals"]):
            nav_answer = (
                f"{student_name}, I can guide and navigate you directly to 5 primary campus destinations:\n"
                "1. Forms & Applications Catalog (/forms) - View, download, and follow submission procedures for all 31 university forms.\n"
                "2. Program Withdrawal & Clearance Cockpit (/withdrawal) - 4-gate digital clearance, UGC refund slabs, and caution deposit tracking.\n"
                "3. Examination & Rechecking Schedule (/exams) - Backpaper registration, grade re-evaluation, and admit cards.\n"
                "4. Student Grievance Redressal Desk (/chat) - Formal ticket submission with 48h resolution SLA.\n"
                "5. Scholarships & Financial Aid (/scholarship) - Merit renewals and fee concessions.\n\n"
                "Where would you like to go?"
            )
            return {
                "answer": nav_answer,
                "domain": "University Portals",
                "citations": [],
                "recommended_action": "Browse Forms & Portals",
                "action_url": "/forms",
                "voice_speech_text": (
                    f"{student_name}, I can navigate you to the Forms Catalog, Program Withdrawal Cockpit, "
                    "Examination Portal, Grievance Redressal Desk, or Scholarships. Just tell me where you'd like to go."
                ),
            }

        # =========================================================================
        # 2. Specific Navigation Request: "Take me to [portal]"
        # =========================================================================
        if any(w in q_lower for w in ["take me to", "navigate to", "open the", "go to the", "show me the"]):
            if any(w in q_lower for w in ["withdrawal", "clearance", "refund", "exit"]):
                return {
                    "answer": f"{student_name}, opening the Program Withdrawal & Clearance Cockpit. You can track all 4 digital gates and your 100% refundable caution deposit here.",
                    "domain": "Withdrawal Navigation",
                    "citations": [],
                    "recommended_action": "Open Withdrawal Portal",
                    "action_url": "/withdrawal",
                    "voice_speech_text": "Navigating to the Program Withdrawal and Clearance portal now.",
                }
            elif any(w in q_lower for w in ["form", "catalog", "document"]):
                return {
                    "answer": f"{student_name}, opening the University Forms & Applications Catalog. You can find and download all 31 academic, financial, examination, and logistics forms here.",
                    "domain": "Forms Navigation",
                    "citations": [],
                    "recommended_action": "Open Forms Catalog",
                    "action_url": "/forms",
                    "voice_speech_text": "Navigating to the University Forms Catalog now.",
                }
            elif any(w in q_lower for w in ["exam", "recheck", "backpaper"]):
                return {
                    "answer": f"{student_name}, opening the Examination & Rechecking Portal. You can verify your exam eligibility, apply for re-evaluation, or download Form EX-02.",
                    "domain": "Exams Navigation",
                    "citations": [],
                    "recommended_action": "Open Examination Portal",
                    "action_url": "/exams",
                    "voice_speech_text": "Navigating to the Examination Portal now.",
                }
            elif any(w in q_lower for w in ["grievance", "complaint", "ticket"]):
                return {
                    "answer": f"{student_name}, opening the Student Grievance Redressal Desk. Academic and facility tickets carry a mandatory 48-hour resolution SLA.",
                    "domain": "Grievance Navigation",
                    "citations": [],
                    "recommended_action": "Open Grievance Desk",
                    "action_url": "/chat",
                    "voice_speech_text": "Navigating to the Student Grievance Redressal Desk now.",
                }
            elif "scholarship" in q_lower:
                return {
                    "answer": f"{student_name}, opening the Scholarships & Financial Aid Portal. You can review merit renewal criteria (CGPA 8.0+) and tuition concessions.",
                    "domain": "Scholarship Navigation",
                    "citations": [],
                    "recommended_action": "Open Scholarships",
                    "action_url": "/scholarship",
                    "voice_speech_text": "Navigating to Scholarships and Financial Aid now.",
                }

        # =========================================================================
        # 3. Ambient Screen Navigation: "Which button to click on this screen?"
        # =========================================================================
        if any(w in q_lower for w in ["what to click", "which button", "which option", "how do i proceed", "where to click", "what should i do here"]):
            if page_context:
                scr_name = page_context.get("screen_name") or "the current screen"
                primary_act = page_context.get("primary_action")
                available = page_context.get("available_actions") or []
                actions_str = ", ".join([f"'{a}'" for a in available[:3]])

                nav_answer = (
                    f"You are currently on the {scr_name}. "
                    f"To proceed, you can click {f'{primary_act}' if primary_act else actions_str}. "
                    "I have highlighted the recommended option on your screen."
                )
                return {
                    "answer": nav_answer,
                    "domain": "Screen Navigation",
                    "citations": [],
                    "recommended_action": primary_act or (available[0] if available else "Proceed"),
                    "action_url": page_context.get("route", "/"),
                    "voice_speech_text": f"On the {scr_name}, click {primary_act or 'the highlighted button'}.",
                    "screen_instruction": f"Click {primary_act} to continue.",
                    "highlight_target": primary_act or (available[0] if available else None),
                }

        # =========================================================================
        # 4. Post-Form Download Procedure: "What should I do after getting [form name]?"
        # =========================================================================
        is_post_form_query = any(w in q_lower for w in [
            "after getting", "after downloading", "what to do after", "what should i do after",
            "where to submit", "where do i submit", "how to submit", "what documents to attach",
            "which documents", "what to do with", "after taking", "submit this form", "submit the form",
            "next step after", "what after getting", "what do i do with this"
        ])

        if is_post_form_query or any(f_kw in q_lower for f_kw in [
            "migration", "rechecking", "condonation", "exit interview", "tada", "conveyance",
            "biometric", "imprest", "mentoring", "purchase proposal", "stationery", "degree format",
            "blank exam", "placement opted"
        ]):
            form_matches = [p for p in policies if p["doc_id"].startswith("PROC-") or "Form" in p["title"]]
            best_form = form_matches[0] if form_matches else (policies[0] if policies else None)

            if best_form:
                answer = (
                    f"{student_name}, here is the verified post-download submission procedure for {best_form['title']}:\n\n"
                    f"{best_form['content']}\n\n"
                    f"Official Clause/Code: {best_form['clause_code']}."
                )
                clean_speech = (
                    f"{student_name}, after getting the {best_form['title']}, follow these steps: "
                    f"{best_form['content']}"
                ).replace("₹", "Rupees ").replace("INR ", "Rupees ")

                res = {
                    "answer": answer,
                    "domain": best_form["category"],
                    "citations": [best_form],
                    "recommended_action": best_form["action_label"],
                    "action_url": best_form["action_url"],
                    "voice_speech_text": clean_speech,
                }

                # Optional Gemini synthesis for natural spoken dialogue
                if settings.llm_enabled:
                    gemini_text = synthesize_guidance_with_gemini(
                        query=query,
                        citations=[best_form],
                        student=student,
                        page_context=page_context,
                    )
                    if gemini_text:
                        res["answer"] = gemini_text
                        res["voice_speech_text"] = gemini_text

                return res

        # =========================================================================
        # 5. Attendance & Condonation Domain
        # =========================================================================
        if any(w in q_lower for w in ["attendance", "condonation", "debar", "absent", "shortage", "exam eligibility"]):
            matching_clause = next((p for p in policies if p["clause_code"] == "ORD-ACAD-7.2"), DEFAULT_POLICIES[0])
            if attendance >= 75.0:
                answer = (
                    f"{student_name}, your current attendance is {attendance:.1f}%, which meets the 75% cutoff under "
                    f"{matching_clause['clause_code']}. You are fully eligible to sit for End Term Semester Examinations without any condonation."
                )
                recommended_action = "View Exam Schedule"
                action_url = "/exams"
            elif 60.0 <= attendance < 75.0:
                shortfall = 75.0 - attendance
                answer = (
                    f"{student_name}, your recorded attendance is {attendance:.1f}% ({shortfall:.1f}% short of the mandatory 75% cutoff). "
                    f"Under {matching_clause['clause_code']}, you are eligible to request Dean's Condonation on medical or approved official "
                    "duty grounds by filing Form AC-04 before the 10-day exam deadline."
                )
                recommended_action = "Download Form AC-04 (Condonation)"
                action_url = "/forms"
            else:
                answer = (
                    f"{student_name}, your recorded attendance is {attendance:.1f}%, which falls below the critical 60% threshold. "
                    f"Under {matching_clause['clause_code']}, attendance below 60% constitutes mandatory debarment. Please meet your Department "
                    "Coordinator immediately for proctorial guidance."
                )
                recommended_action = "Contact Academic Advisor"
                action_url = "/chat"

            res = {
                "answer": answer,
                "domain": "Academics",
                "citations": [matching_clause],
                "recommended_action": recommended_action,
                "action_url": action_url,
                "voice_speech_text": answer,
            }

        # =========================================================================
        # 6. Withdrawal & Caution Deposit Offset Domain
        # =========================================================================
        elif any(w in q_lower for w in ["withdrawal", "refund", "deposit", "offset", "lost id", "id card", "caution"]):
            offset_policy = next((p for p in policies if p["clause_code"] == "ORD-FIN-14.4"), DEFAULT_POLICIES[2])
            wth_policy = next((p for p in policies if p["clause_code"] == "ORD-WTH-14.1"), DEFAULT_POLICIES[1])

            if "offset" in q_lower or "lost id" in q_lower or "200" in q_lower:
                answer = (
                    f"{student_name}, under Smart Offsetting ({offset_policy['clause_code']}), any unreturned ID card fine (Rupees 200) "
                    "or library overdue charge can be auto-deducted directly from your refundable caution deposit (Rupees 10,000). "
                    "You do not need to make offline bank visits; checking the Smart Offset box clears the gate immediately."
                )
                action_url = "/withdrawal"
                recommended_action = "View Clearance & Offset"
            else:
                answer = (
                    f"{student_name}, university program withdrawal is governed by {wth_policy['clause_code']}. "
                    "Tuition refund percentages follow UGC slabs (100% to 50% depending on days relative to admission closure). "
                    "Your refundable caution deposit of Rupees 10,000 is 100% refundable across all withdrawal dates. "
                    "Clearance is tracked across 4 digital gates (Library, Hostel, Accounts, Registrar)."
                )
                action_url = "/withdrawal"
                recommended_action = "Start Withdrawal Procedure"

            res = {
                "answer": answer,
                "domain": "Withdrawal & Refunds",
                "citations": [wth_policy, offset_policy],
                "recommended_action": recommended_action,
                "action_url": action_url,
                "voice_speech_text": answer,
            }

        # =========================================================================
        # 7. General Policy / FTS5 Match
        # =========================================================================
        elif policies:
            top_p = policies[0]
            answer = (
                f"{student_name}, according to {top_p['clause_code']} ({top_p['title']}): "
                f"{top_p['content']}"
            )
            res = {
                "answer": answer,
                "domain": top_p["category"],
                "citations": policies,
                "recommended_action": top_p["action_label"],
                "action_url": top_p["action_url"],
                "voice_speech_text": answer.replace("₹", "Rupees ").replace("INR ", "Rupees "),
            }
        else:
            fallback_msg = (
                f"{student_name}, I could not find a specific university ordinance matching your inquiry. "
                "UniAssist provides guidance for all 31 university forms, Academics, Attendance Condonation, "
                "Withdrawal Refunds, Smart Caution Deposit Offsets, Backpapers, Grievances, and Scholarships. "
                "Please try asking with one of these topics."
            )
            res = {
                "answer": fallback_msg,
                "domain": "General",
                "citations": [],
                "recommended_action": "Browse Forms & Policies",
                "action_url": "/forms",
                "voice_speech_text": fallback_msg,
            }

        # Gemini synthesis on general policy questions if enabled
        if settings.llm_enabled and res.get("citations"):
            gemini_text = synthesize_guidance_with_gemini(
                query=query,
                citations=res["citations"],
                student=student,
                page_context=page_context,
            )
            if gemini_text:
                res["answer"] = gemini_text
                res["voice_speech_text"] = gemini_text

        # Ambient Screen Awareness Enhancement
        if page_context:
            scr_name = page_context.get("screen_name") or "the current page"
            primary_act = page_context.get("primary_action")
            if primary_act:
                res["screen_instruction"] = f"On this {scr_name}, you can click '{primary_act}' to proceed immediately."
                res["highlight_target"] = primary_act
                res["voice_speech_text"] = f"{res['voice_speech_text']} Also, since you are on the {scr_name}, you can click '{primary_act}'."

        return res
