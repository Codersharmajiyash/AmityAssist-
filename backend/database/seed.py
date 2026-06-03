"""
Database schema creation and sample data seeding.

Security note: All INSERT statements use parameterised queries.
INSERT OR IGNORE makes repeated startups idempotent without duplicating data.
"""

from .connection import get_connection

# ---------------------------------------------------------------------------
# DDL
# ---------------------------------------------------------------------------

_SCHEMA = """
CREATE TABLE IF NOT EXISTS students (
    id            TEXT PRIMARY KEY,
    name          TEXT NOT NULL,
    email         TEXT UNIQUE NOT NULL,
    course        TEXT NOT NULL,
    branch        TEXT NOT NULL,
    semester      INTEGER NOT NULL,
    enrolled_date TEXT NOT NULL,
    attendance    REAL NOT NULL DEFAULT 75.0,
    cgpa          REAL NOT NULL DEFAULT 7.0,
    fee_status    TEXT NOT NULL DEFAULT 'Paid' CHECK(fee_status IN ('Paid', 'Pending')),
    fee_due       REAL NOT NULL DEFAULT 0.0,
    hostel_status TEXT NOT NULL DEFAULT 'Day Scholar',
    scholarship_status TEXT NOT NULL DEFAULT 'None',
    academic_performance TEXT NOT NULL DEFAULT 'Good',
    interests     TEXT,
    previous_interactions INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS users (     
    username      TEXT PRIMARY KEY,
    name          TEXT NOT NULL,
    role          TEXT NOT NULL CHECK(role IN ('Faculty', 'Department Coordinator', 'Finance Department', 'Scholarship Department', 'Examination Cell', 'Registrar', 'Admission Team', 'Administrator'))
);

CREATE TABLE IF NOT EXISTS conversations (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id      TEXT    NOT NULL,
    message         TEXT    NOT NULL,
    sender          TEXT    NOT NULL CHECK(sender IN ('student', 'bot')),
    detected_intent TEXT,
    sentiment       TEXT,
    timestamp       DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(student_id) REFERENCES students(id)
);

CREATE TABLE IF NOT EXISTS withdrawal_requests (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id      TEXT    NOT NULL,
    reason          TEXT    NOT NULL,
    detected_intent TEXT,
    refund_amount   REAL    DEFAULT 0.0,
    status          TEXT    NOT NULL DEFAULT 'pending'
                    CHECK(status IN ('pending', 'approved', 'rejected')),
    timestamp       DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(student_id) REFERENCES students(id)
);

CREATE TABLE IF NOT EXISTS documents (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id      TEXT    NOT NULL,
    file_name       TEXT    NOT NULL,
    file_path       TEXT    NOT NULL,
    classification  TEXT    DEFAULT 'other',
    ocr_data        TEXT,
    verification_status TEXT DEFAULT 'pending' CHECK(verification_status IN ('pending', 'verified', 'fraud_detected', 'error')),
    verification_notes  TEXT,
    timestamp       DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(student_id) REFERENCES students(id)
);

CREATE TABLE IF NOT EXISTS notices (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    title         TEXT NOT NULL,
    content       TEXT NOT NULL,
    target_branch TEXT NOT NULL, -- "CSE", "ECE", "MBA", "Biotech", or "ALL"
    target_semester INTEGER NOT NULL, -- 0 for "ALL", or 1-8
    category      TEXT NOT NULL CHECK(category IN ('academics', 'exam', 'scholarship', 'internship', 'general')),
    timestamp     DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS scholarships (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    name          TEXT NOT NULL,
    description   TEXT NOT NULL,
    eligibility_cgpa REAL NOT NULL,
    amount        REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS scholarship_applications (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id    TEXT NOT NULL,
    scholarship_id INTEGER NOT NULL,
    status        TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'approved', 'rejected')),
    timestamp     DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(student_id) REFERENCES students(id),
    FOREIGN KEY(scholarship_id) REFERENCES scholarships(id)
);

CREATE TABLE IF NOT EXISTS examinations (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id    TEXT NOT NULL,
    subject_code  TEXT NOT NULL,
    subject_name  TEXT NOT NULL,
    exam_date     TEXT NOT NULL,
    grade         TEXT, -- NULL if exam has not happened yet
    type          TEXT NOT NULL DEFAULT 'regular' CHECK(type IN ('regular', 'backpaper')),
    backpaper_status TEXT DEFAULT 'none' CHECK(backpaper_status IN ('none', 'registered', 'paid')),
    FOREIGN KEY(student_id) REFERENCES students(id)
);

CREATE TABLE IF NOT EXISTS grievances (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id    TEXT NOT NULL,
    category      TEXT NOT NULL CHECK(category IN ('academic', 'fee', 'hostel', 'exam', 'scholarship')),
    description   TEXT NOT NULL,
    status        TEXT NOT NULL DEFAULT 'open' CHECK(status IN ('open', 'in_progress', 'resolved')),
    resolution    TEXT,
    timestamp     DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(student_id) REFERENCES students(id)
);

CREATE TABLE IF NOT EXISTS internships (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    title         TEXT NOT NULL,
    company       TEXT NOT NULL,
    description   TEXT NOT NULL,
    required_cgpa REAL NOT NULL,
    stipend       TEXT NOT NULL,
    deadline      TEXT NOT NULL
);
"""

# ---------------------------------------------------------------------------
# Sample Records
# ---------------------------------------------------------------------------

_SAMPLE_STUDENTS = [
    ("STU001", "Aisha Malik", "aisha.malik@uni.edu", "Computer Science", "CSE", 6, "2023-07-15", 82.5, 8.75, "Paid", 0.0, "Allocated (Hostel-3)", "50% Merit Scholarship", "Outstanding", "Artificial Intelligence, Web Development", 12),
    ("STU002", "Rahul Sharma", "rahul.sharma@uni.edu", "Electrical Engineering", "ECE", 4, "2024-07-15", 68.0, 5.8, "Pending", 1850.0, "Day Scholar", "None", "Needs Improvement", "Embedded Systems, Robotics", 8),
    ("STU003", "Priya Nair", "priya.nair@uni.edu", "Business Administration", "MBA", 2, "2025-01-10", 91.2, 9.1, "Paid", 0.0, "Day Scholar", "100% VC Fellowship", "Outstanding", "Finance, Public Speaking", 4),
    ("STU004", "James Osei", "james.osei@uni.edu", "Data Science", "CSE", 8, "2022-07-15", 74.5, 7.20, "Paid", 0.0, "Allocated (Hostel-1)", "None", "Good", "Machine Learning, R Programming", 15),
    ("STU005", "Fatima Al-Hassan", "fatima.alhassan@uni.edu", "Biotechnology", "Biotech", 2, "2025-07-15", 85.0, 7.90, "Paid", 0.0, "Allocated (Hostel-2)", "None", "Good", "Genetics, Cell Biology", 2),
    ("STU006", "Chen Wei", "chen.wei@uni.edu", "Mechanical Engineering", "Mechanical Engineering", 6, "2023-07-15", 77.8, 6.90, "Paid", 0.0, "Day Scholar", "None", "Good", "Automotive Design, CAD", 6),
    ("STU007", "Sofia Gonzalez", "sofia.gonzalez@uni.edu", "Psychology", "Psychology", 8, "2022-07-15", 89.0, 8.40, "Paid", 0.0, "Day Scholar", "25% Merit Scholarship", "Good", "Cognitive Studies, Therapy", 9),
    ("STU008", "Amara Diallo", "amara.diallo@uni.edu", "Architecture", "Architecture", 4, "2024-07-15", 81.2, 7.50, "Paid", 0.0, "Allocated (Hostel-4)", "None", "Good", "Urban Planning, Sustainable Design", 7),
    ("STU009", "Lucas Ferreira", "lucas.ferreira@uni.edu", "Civil Engineering", "Civil Engineering", 6, "2023-07-15", 64.5, 6.10, "Pending", 1200.0, "Day Scholar", "None", "Average", "Structural Analysis, Surveying", 11),
    ("STU010", "Mei Lin", "mei.lin@uni.edu", "Pharmacy", "Pharmacy", 2, "2025-07-15", 94.0, 9.30, "Paid", 0.0, "Allocated (Hostel-3)", "100% VC Fellowship", "Outstanding", "Pharmacology, Drug Chemistry", 3)
]

_SAMPLE_USERS = [
    ("registrar_staff", "Registrar Office Support", "Registrar"),
    ("admission_staff", "Admissions Helpdesk", "Admission Team"),
    ("finance_staff", "Finance Advisor Office", "Finance Department"),
    ("scholarship_staff", "Scholarship Desk Coordinator", "Scholarship Department"),
    ("exam_staff", "Examination Cell Controller", "Examination Cell"),
    ("coordinator_staff", "Academic Department Coordinator", "Department Coordinator")
]

_SAMPLE_NOTICES = [
    ("Mid-Semester Examinations Datesheet", "Mid-Semester Examinations for all undergraduate programs will commence on Oct 12, 2026. The detailed subject datesheet is available on the portal. Please ensure you clear any outstanding fees to receive your admit card.", "ALL", 0, "exam"),
    ("Wipro Campus Placement Internship Drive 2026", "Wipro is conducting an internship selection drive for CSE and ECE students of the 6th semester. Minimum required CGPA is 8.0. Register by June 25, 2026.", "CSE", 6, "internship"),
    ("Biotech Research Lab Renovation Notice", "The Biotech research labs will remain closed for maintenance and instrumentation upgrading from June 10 to June 15. Students requiring lab space can request reallocation from the Coordinator.", "Biotech", 0, "academics"),
    ("Merit Scholarship Renewal Application Open", "Applications for the renewal of Merit and VC Scholarships for the academic year 2026-27 are now open. Eligible students must submit their CGPA scorecards online by June 20, 2026.", "ALL", 0, "scholarship"),
    ("Academic Advisory Committee Grievance Cell Meeting", "The next meeting of the Student Grievance Redressal Committee is scheduled for June 18. Students who have logged grievances can join the open house at 2:00 PM in Block F-3.", "ALL", 0, "general"),
    ("ECE Electronics Lab Practical Datesheet", "The practical exams for Electronics circuits (semester 4) will be held from June 15 to June 17. Please contact your lab instructor for batch details.", "ECE", 4, "exam"),
    ("Microsoft Software Development Internship Opportunity", "Microsoft is offering summer internships for pre-final year students (semester 6). Stipend: 80,000 INR/month. Minimum CGPA: 8.5. CSE/ECE eligible.", "ALL", 6, "internship")
]

_SAMPLE_SCHOLARSHIPS = [
    ("Amity Merit Scholarship", "50% tuition fee waiver for academic toppers with CGPA 8.0 or above.", 8.0, 120000.0),
    ("Vice Chancellor's Fellowship", "100% tuition fee waiver for outstanding students with CGPA 9.0 or above.", 9.0, 240000.0),
    ("Sports Excellence Award", "25% fee waiver for students representing the university at state/national sports events.", 6.0, 60000.0)
]

_SAMPLE_EXAMINATIONS = [
    # Aisha Malik
    ("STU001", "CSE-301", "Computer Networks", "2025-11-20", "A", "regular", "none"),
    ("STU001", "CSE-302", "Software Engineering", "2025-11-22", "A+", "regular", "none"),
    ("STU001", "CSE-303", "Artificial Intelligence", "2025-11-25", "B+", "regular", "none"),
    ("STU001", "CSE-304", "Web Technology", "2026-06-12", None, "regular", "none"),
    ("STU001", "CSE-305", "Automata Theory", "2026-06-15", None, "regular", "none"),
    
    # Rahul Sharma
    ("STU002", "ECE-201", "Signals and Systems", "2025-11-18", "F", "regular", "registered"),
    ("STU002", "ECE-202", "Digital Circuit Design", "2025-11-20", "D", "regular", "none"),
    ("STU002", "ECE-203", "Analog Communications", "2025-11-23", "C+", "regular", "none"),
    ("STU002", "ECE-204", "Microprocessors", "2026-06-13", None, "regular", "none"),
    
    # Priya Nair
    ("STU003", "MBA-101", "Managerial Economics", "2025-05-15", "O", "regular", "none"),
    ("STU003", "MBA-102", "Financial Accounting", "2025-05-18", "A+", "regular", "none")
]

_SAMPLE_INTERNSHIPS = [
    ("Software Development Intern", "Google India", "Work on cutting-edge features for Google Cloud Platform. Requires strong DSA and Java/Python skills.", 8.5, "85,000 INR/month", "2026-08-30"),
    ("Data Analyst Intern", "Microsoft", "Analyze user behavior metrics and help design data dashboards. Requires SQL and PowerBI.", 8.0, "70,000 INR/month", "2026-09-15"),
    ("Robotics Systems Trainee", "Tesla India", "Build controllers and simulations for autonomous systems. Requires ROS, C++, and kinematics.", 8.2, "60,000 INR/month", "2026-07-20"),
    ("Research Associate (Biotech)", "Biocon", "Work in the gene-editing labs assisting senior molecular biologists. Requires biology background.", 7.5, "35,000 INR/month", "2026-06-30")
]


def init_db() -> None:
    """Create tables and insert rich sample lifecycle data — safe to call multiple times."""
    conn = get_connection()
    cursor = conn.cursor()
    
    # Schema Migration Check: If 'cgpa' column is missing from students, recreate everything
    schema_ok = True
    try:
        cursor.execute("SELECT cgpa FROM students LIMIT 1")
    except Exception:
        schema_ok = False
        
    if not schema_ok:
        print("[DB] Dropping outdated tables to load expanded Student Lifecycle schema...")
        cursor.execute("DROP TABLE IF EXISTS conversations")
        cursor.execute("DROP TABLE IF EXISTS withdrawal_requests")
        cursor.execute("DROP TABLE IF EXISTS documents")
        cursor.execute("DROP TABLE IF EXISTS students")
        cursor.execute("DROP TABLE IF EXISTS users")
        cursor.execute("DROP TABLE IF EXISTS notices")
        cursor.execute("DROP TABLE IF EXISTS scholarships")
        cursor.execute("DROP TABLE IF EXISTS scholarship_applications")
        cursor.execute("DROP TABLE IF EXISTS examinations")
        cursor.execute("DROP TABLE IF EXISTS grievances")
        cursor.execute("DROP TABLE IF EXISTS internships")
        conn.commit()

    # Create all tables
    cursor.executescript(_SCHEMA)
    conn.commit()

    # Seed students
    cursor.executemany(
        "INSERT OR IGNORE INTO students (id, name, email, course, branch, semester, enrolled_date, attendance, cgpa, fee_status, fee_due, hostel_status, scholarship_status, academic_performance, interests, previous_interactions) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        _SAMPLE_STUDENTS,
    )
    
    # Seed users (staff)
    cursor.executemany(
        "INSERT OR IGNORE INTO users (username, name, role) VALUES (?, ?, ?)",
        _SAMPLE_USERS
    )

    # Seed notices
    cursor.executemany(
        "INSERT OR IGNORE INTO notices (title, content, target_branch, target_semester, category) VALUES (?, ?, ?, ?, ?)",
        _SAMPLE_NOTICES
    )

    # Seed scholarships
    cursor.executemany(
        "INSERT OR IGNORE INTO scholarships (name, description, eligibility_cgpa, amount) VALUES (?, ?, ?, ?)",
        _SAMPLE_SCHOLARSHIPS
    )

    # Seed examinations
    cursor.executemany(
        "INSERT OR IGNORE INTO examinations (student_id, subject_code, subject_name, exam_date, grade, type, backpaper_status) VALUES (?, ?, ?, ?, ?, ?, ?)",
        _SAMPLE_EXAMINATIONS
    )

    # Seed internships
    cursor.executemany(
        "INSERT OR IGNORE INTO internships (title, company, description, required_cgpa, stipend, deadline) VALUES (?, ?, ?, ?, ?, ?)",
        _SAMPLE_INTERNSHIPS
    )

    conn.commit()
    print("[DB] Expanded Student Lifecycle Database seeded successfully.")
