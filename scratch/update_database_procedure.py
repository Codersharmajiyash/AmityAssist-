import sqlite3
import json
from datetime import datetime, timezone

db_path = r'c:\Users\prade\Uniassist\AmityAssist-\database\chatbot.db'
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

now_iso = datetime.now(timezone.utc).isoformat()

# 1. Update/Insert in custom_procedures
proc_id = "proc-degree-application"
title = "Degree Certificate Application Procedure (Passed Out Batches Up to 2025)"
department = "Controller of Examinations / Degree Cell"
category = "EXAMINATIONS"
description = (
    "Official procedure for students of passed out batches up to 2025 to apply for and obtain their University Degree Certificate. "
    "Requires No Dues clearance, Rs. 1100 degree fee (plus Rs. 400 courier charges if by post), signed application form, and email acknowledgement."
)
sla_days = 10
required_docs = json.dumps([
    "Duly filled in application form signed by candidate (09. Degree Application Format)",
    "University No-Dues Clearance slip",
    "Online fee payment transaction receipt (Rs. 1100 / Rs. 1500)",
    "Photo ID proof of candidate or parent (if collecting in person)"
])

cursor.execute("""
INSERT OR REPLACE INTO custom_procedures 
(id, title, department, category, description, sla_days, required_docs, is_active, created_by, created_at, updated_at, institution_name)
VALUES (?, ?, ?, ?, ?, ?, ?, 1, 'STAFF_ADMIN', ?, ?, 'Amity University')
""", (proc_id, title, department, category, description, sla_days, required_docs, now_iso, now_iso))

# 2. Insert the 7 custom_procedure_steps
cursor.execute("DELETE FROM custom_procedure_steps WHERE procedure_id = ?", (proc_id,))

steps = [
    (1, "Clear University No Dues", "Before applying for Degree certificate No Dues should be cleared.", "Finance & Clearance Desk", 1),
    (2, "Batch Eligibility Verification", "Students of passed out batches up to 2025 who are required degree may apply for obtaining the degree certificate.", "Examination Records Desk", 1),
    (3, "Fill & Sign Application Form", "Candidate must submit the duly filled in application form after it is signed by him/her.", "Student / Candidate", 1),
    (4, "Online Fee Payment (Rs. 1,100/-)", "Fee of Rs. 1100/- for Degree Certificate to be paid through online (Google Pay, PhonePe, NEFT) in the account of Amity University Madhya Pradesh (Account Name: Amity University Madhya Pradesh, Account No. 911010033371991, Bank Name: Axis Bank Ltd, Bank Branch: City Centre, Gwalior, IFSC Code: UTIB0000158).", "Online Payment / Accounts", 1),
    (5, "Courier Charges (Rs. 400/- if by Post)", "If the Degree certificate required by post the Courier charges of Rs. 400/- also to be paid to the same university account (Total: Rs. 1,500/-).", "Postal Dispatch Desk", 1),
    (6, "Certificate Handover or Dispatch", "The degree certificate shall be given to the candidate or to his/her parent only. In case if the candidate or parent is not able to collect in person, it is dispatched via courier.", "Degree Cell / Controller of Examinations", 7),
    (7, "Email Acknowledgement of Receipt", "Candidate must acknowledge the receipt of degree through email upon delivery.", "Student / Examination Cell", 1),
]

for s_num, s_title, s_desc, s_desk, s_sla in steps:
    step_id = f"step-deg-{s_num}"
    cursor.execute("""
    INSERT INTO custom_procedure_steps (id, procedure_id, step_number, title, description, responsible_desk, sla_days, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (step_id, proc_id, s_num, s_title, s_desc, s_desk, s_sla, now_iso))

# 3. Update/Insert in university_policies
policy_doc_id = "PROC-FORM-DEGREE"
policy_content = (
    "Official procedure for applying for Degree Certificate:\n"
    "1. Before applying for Degree certificate No Dues should be cleared.\n"
    "2. Students of passed out batches up to 2025 who are required degree may apply for obtaining the degree certificate.\n"
    "3. Candidate must submit the duly filled in application form after it is signed by him/her.\n"
    "4. Fee of Rs. 1100/- for Degree Certificate to be paid through online (Google Pay, PhonePe, NEFT) in the account of Amity University Madhya Pradesh.\n"
    "   Detail of account: Account Name: Amity University Madhya Pradesh, Account No. 911010033371991, Bank Name: Axis Bank Ltd, Bank Branch: City Centre, Gwalior, IFSC Code: UTIB0000158.\n"
    "5. If the Degree certificate required by post the Courier charges of Rs. 400/- also to be paid (Total: Rs. 1500/-).\n"
    "6. The degree certificate shall be given to the candidate or to his/her parent only (if collecting in person, or dispatched via courier).\n"
    "7. Candidate must acknowledge the receipt of degree through email."
)

cursor.execute("""
INSERT OR REPLACE INTO university_policies
(doc_id, category, title, clause_code, content, action_url, action_label, is_custom, updated_at)
VALUES (?, 'Examinations', ?, 'FORM-DEG-09', ?, '/forms/09.%20Degree%20Application%20Format%20(1).pdf', 'Download Degree Application Form', 0, ?)
""", (policy_doc_id, title, policy_content, now_iso))

# 4. Re-index in policy_fts if exists
try:
    cursor.execute("DELETE FROM policy_fts WHERE doc_id = ?", (policy_doc_id,))
    cursor.execute("""
    INSERT INTO policy_fts (doc_id, title, content, category)
    VALUES (?, ?, ?, 'Examinations')
    """, (policy_doc_id, title, policy_content))
    print("Re-indexed into policy_fts successfully.")
except Exception as e:
    print("policy_fts sync notice:", e)

# 5. Update forms_catalog description for 09. Degree Application Format (1).pdf
cursor.execute("""
UPDATE forms_catalog 
SET name = 'Degree Certificate Application Form (09)',
    description = 'Official Degree Certificate Application Form for passed out batches up to 2025. Fee: Rs. 1100 (plus Rs. 400 courier if by post). Account No: 911010033371991, Axis Bank, IFSC: UTIB0000158.'
WHERE file_name = '09. Degree Application Format (1).pdf'
""")

conn.commit()
conn.close()
print("Database procedure update complete!")
