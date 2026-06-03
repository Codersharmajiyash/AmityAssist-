"""
Student lifecycle API endpoints.

Provides personalized data for dashboard, academics, scholarships,
notices, grievances, internships, and back-paper registration.
"""
from fastapi import APIRouter, HTTPException, Query
from ..database.connection import get_connection
from ..models.schemas import BackpaperRequest, GrievanceCreate, ScholarshipApply

router = APIRouter(prefix="/api/student", tags=["Student"])


def _normalise_student_id(student_id: str) -> str:
    return student_id.upper().strip()


# ── Profile ───────────────────────────────────────────────────────────────────
def _fetch_profile(student_id: str):
    """Return full student profile for dashboard personalization."""
    conn = get_connection()
    row = conn.execute(
        "SELECT * FROM students WHERE id = ?", (_normalise_student_id(student_id),)
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Student not found.")
    return dict(row)


@router.get("/profile")
async def get_profile(student_id: str = Query(..., min_length=3, max_length=20)):
    """Return full student profile for dashboard personalization."""
    return _fetch_profile(student_id)


@router.get("/profile/{student_id}")
async def get_profile_by_path(student_id: str):
    """Compatibility route for existing callers that use path parameters."""
    return _fetch_profile(student_id)


# ── Personalized Notices ───────────────────────────────────────────────────────
def _fetch_notices(student_id: str):
    """Return notices personalized to student's branch and semester."""
    conn = get_connection()
    student = conn.execute(
        "SELECT branch, semester FROM students WHERE id = ?",
        (_normalise_student_id(student_id),)
    ).fetchone()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    branch = student["branch"]
    semester = student["semester"]

    rows = conn.execute(
        """SELECT * FROM notices
           WHERE (target_branch = 'ALL' OR target_branch = ?)
             AND (target_semester = 0 OR target_semester = ?)
           ORDER BY timestamp DESC""",
        (branch, semester)
    ).fetchall()
    return [dict(r) for r in rows]


@router.get("/notices")
async def get_notices(student_id: str = Query(..., min_length=3, max_length=20)):
    """Return notices personalized to student's branch and semester."""
    return _fetch_notices(student_id)


@router.get("/notices/{student_id}")
async def get_notices_by_path(student_id: str):
    """Compatibility route for existing callers that use path parameters."""
    return _fetch_notices(student_id)


# ── Examinations & Results ─────────────────────────────────────────────────────
def _fetch_exams(student_id: str):
    """Return exam schedule, grades, and back-paper status for a student."""
    conn = get_connection()
    student = conn.execute(
        "SELECT id FROM students WHERE id = ?",
        (_normalise_student_id(student_id),),
    ).fetchone()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")
    rows = conn.execute(
        "SELECT * FROM examinations WHERE student_id = ? ORDER BY exam_date ASC",
        (_normalise_student_id(student_id),)
    ).fetchall()
    return [dict(r) for r in rows]


@router.get("/exams")
async def get_exams(student_id: str = Query(..., min_length=3, max_length=20)):
    """Return exam schedule, grades, and back-paper status for a student."""
    return _fetch_exams(student_id)


@router.get("/exams/{student_id}")
async def get_exams_by_path(student_id: str):
    """Compatibility route for existing callers that use path parameters."""
    return _fetch_exams(student_id)


# ── Back Paper Registration ────────────────────────────────────────────────────
def _register_backpaper(body: BackpaperRequest):
    """Register a student for a back-paper exam."""
    conn = get_connection()
    row = conn.execute(
        "SELECT * FROM examinations WHERE id = ? AND student_id = ?",
        (body.exam_id, body.student_id)
    ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Exam record not found.")
    if row["grade"] not in (None, "F", "D"):
        raise HTTPException(status_code=400, detail="Back paper not applicable for this exam.")
    conn.execute(
        "UPDATE examinations SET backpaper_status = 'registered' WHERE id = ?",
        (body.exam_id,)
    )
    conn.commit()
    return {"message": f"Back paper registered for {row['subject_name']}. Fee payment pending."}


@router.post("/backpaper")
async def register_backpaper(body: BackpaperRequest):
    """Register a student for a back-paper exam."""
    return _register_backpaper(body)


@router.post("/backpaper/register")
async def register_backpaper_compat(body: BackpaperRequest):
    """Compatibility route for existing callers."""
    return _register_backpaper(body)


# ── Scholarships ───────────────────────────────────────────────────────────────
def _fetch_scholarships(student_id: str):
    """Return all scholarships and eligibility status for the student."""
    conn = get_connection()
    student = conn.execute(
        "SELECT cgpa FROM students WHERE id = ?",
        (_normalise_student_id(student_id),)
    ).fetchone()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    schemes = conn.execute("SELECT * FROM scholarships").fetchall()
    applied = conn.execute(
        "SELECT scholarship_id, status FROM scholarship_applications WHERE student_id = ?",
        (_normalise_student_id(student_id),)
    ).fetchall()
    applied_map = {r["scholarship_id"]: r["status"] for r in applied}

    result = []
    for s in schemes:
        eligible = student["cgpa"] >= s["eligibility_cgpa"]
        result.append({
            **dict(s),
            "eligible": eligible,
            "application_status": applied_map.get(s["id"], None)
        })
    return result


@router.get("/scholarships")
async def get_scholarships(student_id: str = Query(..., min_length=3, max_length=20)):
    """Return all scholarships and eligibility status for the student."""
    return _fetch_scholarships(student_id)


@router.get("/scholarships/{student_id}")
async def get_scholarships_by_path(student_id: str):
    """Compatibility route for existing callers that use path parameters."""
    return _fetch_scholarships(student_id)


# ── Apply for Scholarship ──────────────────────────────────────────────────────
@router.post("/scholarships/apply")
async def apply_scholarship(body: ScholarshipApply):
    """Auto-apply student for a scholarship if eligible."""
    conn = get_connection()
    student = conn.execute(
        "SELECT cgpa FROM students WHERE id = ?",
        (body.student_id,)
    ).fetchone()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    scheme = conn.execute(
        "SELECT * FROM scholarships WHERE id = ?", (body.scholarship_id,)
    ).fetchone()
    if not scheme:
        raise HTTPException(status_code=404, detail="Scholarship not found.")

    if student["cgpa"] < scheme["eligibility_cgpa"]:
        raise HTTPException(
            status_code=400,
            detail=f"Not eligible. Required CGPA: {scheme['eligibility_cgpa']}, Your CGPA: {student['cgpa']}"
        )

    existing = conn.execute(
        "SELECT id FROM scholarship_applications WHERE student_id = ? AND scholarship_id = ?",
        (body.student_id, body.scholarship_id)
    ).fetchone()
    if existing:
        raise HTTPException(status_code=400, detail="Already applied for this scholarship.")

    conn.execute(
        "INSERT INTO scholarship_applications (student_id, scholarship_id, status) VALUES (?, ?, 'pending')",
        (body.student_id, body.scholarship_id)
    )
    conn.commit()
    return {"message": f"Application submitted for '{scheme['name']}'. Under review."}


# ── Grievances ────────────────────────────────────────────────────────────────
@router.post("/grievances")
async def file_grievance(body: GrievanceCreate):
    """File a new student grievance."""
    allowed = ("academic", "fee", "hostel", "exam", "scholarship")
    if body.category not in allowed:
        raise HTTPException(status_code=400, detail=f"Category must be one of: {', '.join(allowed)}")
    conn = get_connection()
    conn.execute(
        "INSERT INTO grievances (student_id, category, description) VALUES (?, ?, ?)",
        (body.student_id, body.category, body.description)
    )
    conn.commit()
    return {"message": "Grievance filed successfully. You will receive a response within 3 working days."}

def _fetch_grievances(student_id: str):
    """Return all grievances for a student."""
    conn = get_connection()
    student = conn.execute(
        "SELECT id FROM students WHERE id = ?",
        (_normalise_student_id(student_id),),
    ).fetchone()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")
    rows = conn.execute(
        "SELECT * FROM grievances WHERE student_id = ? ORDER BY timestamp DESC",
        (_normalise_student_id(student_id),)
    ).fetchall()
    return [dict(r) for r in rows]


@router.get("/grievances")
async def get_grievances(student_id: str = Query(..., min_length=3, max_length=20)):
    """Return all grievances for a student."""
    return _fetch_grievances(student_id)


@router.get("/grievances/{student_id}")
async def get_grievances_by_path(student_id: str):
    """Compatibility route for existing callers that use path parameters."""
    return _fetch_grievances(student_id)


# ── Internships ───────────────────────────────────────────────────────────────
def _fetch_internships(student_id: str):
    """Return internship opportunities relevant to a student's CGPA."""
    conn = get_connection()
    student = conn.execute(
        "SELECT cgpa FROM students WHERE id = ?",
        (_normalise_student_id(student_id),)
    ).fetchone()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found.")

    rows = conn.execute(
        "SELECT * FROM internships ORDER BY deadline ASC"
    ).fetchall()

    result = []
    for r in rows:
        d = dict(r)
        d["eligible"] = student["cgpa"] >= r["required_cgpa"]
        result.append(d)
    return result


@router.get("/internships")
async def get_internships(student_id: str = Query(..., min_length=3, max_length=20)):
    """Return internship opportunities relevant to a student's CGPA."""
    return _fetch_internships(student_id)


@router.get("/internships/{student_id}")
async def get_internships_by_path(student_id: str):
    """Compatibility route for existing callers that use path parameters."""
    return _fetch_internships(student_id)
