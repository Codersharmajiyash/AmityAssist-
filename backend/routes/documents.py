"""
Document management with simulated Document AI OCR and fraud detection.

Mock services:
  - OCR: Simulates text extraction from documents
  - Fraud Detection: Checks for tampered signatures, mismatched names, altered text
  - Verification: Staff can manually verify or flag documents
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from pydantic import BaseModel
import shutil
import uuid
import json
import random
from pathlib import Path
from ..database.connection import get_connection

router = APIRouter(prefix="/api/documents", tags=["Documents"])

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)

ALLOWED_EXTENSIONS = {".pdf", ".jpg", ".jpeg", ".png"}

# ── Mock Document AI Service ──────────────────────────────────────────────────
def simulate_ocr_analysis(filename: str, student_id: str) -> dict:
    """
    Simulate Document AI OCR extraction.
    Returns mock OCR data and fraud detection flags.
    """
    # Mock OCR extraction
    ocr_data = {
        "extracted_name": "Aisha Malik",
        "extracted_student_id": student_id,
        "extracted_date": "2024-05-15",
        "confidence_score": round(random.uniform(0.85, 0.99), 2),
        "document_type": "ID Card" if "id" in filename.lower() else "Medical Certificate",
        "image_quality_score": round(random.uniform(0.75, 0.98), 2),
        "signature_detected": True,
        "stamp_detected": True,
    }
    
    # Mock fraud detection
    fraud_flags = []
    
    # Check for signature tampering (simulated)
    if random.random() < 0.05:  # 5% chance
        fraud_flags.append("Signature mismatch detected")
    
    # Check for text alteration (simulated)
    if random.random() < 0.03:  # 3% chance
        fraud_flags.append("Text alteration suspected")
    
    # Check for duplicate (simulated)
    if random.random() < 0.02:  # 2% chance
        fraud_flags.append("Potential duplicate submission")
    
    # Image quality check
    if ocr_data["image_quality_score"] < 0.60:
        fraud_flags.append("Image quality too low for verification")
    
    return {
        "ocr_data": ocr_data,
        "fraud_flags": fraud_flags,
        "overall_status": "FRAUD_DETECTED" if fraud_flags else "CLEAN"
    }


# ── Upload Document with OCR Analysis ──────────────────────────────────────────
@router.post("/upload")
async def upload_document(
    file: UploadFile = File(...),
    student_id: str = Form(...)
):
    """
    Upload document and run mock Document AI OCR + fraud detection.
    """
    # Validate extension
    ext = Path(file.filename).suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Invalid file type. Only PDF, JPG, and PNG are allowed.")
    
    # Secure filename
    secure_name = f"{student_id}_{uuid.uuid4().hex[:8]}{ext}"
    file_path = UPLOAD_DIR / secure_name

    # Save to disk
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Run mock Document AI analysis
    analysis_result = simulate_ocr_analysis(file.filename, student_id)
    
    # Save to DB with OCR results
    conn = get_connection()
    try:
        verification_status = "fraud_detected" if analysis_result["fraud_flags"] else "pending"
        ocr_json = json.dumps(analysis_result["ocr_data"])
        fraud_notes = "; ".join(analysis_result["fraud_flags"]) if analysis_result["fraud_flags"] else None
        
        conn.execute(
            """INSERT INTO documents 
               (student_id, file_name, file_path, classification, ocr_data, verification_status, verification_notes) 
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (student_id, file.filename, str(file_path), 
             analysis_result["ocr_data"]["document_type"], 
             ocr_json, 
             verification_status,
             fraud_notes)
        )
        conn.commit()
    except Exception as e:
        raise HTTPException(status_code=500, detail="Database error while saving document record.")
    
    return {
        "message": "Document uploaded successfully",
        "file_name": file.filename,
        "ocr_data": analysis_result["ocr_data"],
        "fraud_flags": analysis_result["fraud_flags"],
        "overall_status": analysis_result["overall_status"],
        "verification_status": verification_status
    }


# ── Retrieve Documents for Audit ────────────────────────────────────────────────
@router.get("/list/{student_id}")
async def get_student_documents(student_id: str):
    """Get all documents uploaded by a student."""
    conn = get_connection()
    rows = conn.execute(
        "SELECT * FROM documents WHERE student_id = ? ORDER BY timestamp DESC",
        (student_id.upper().strip(),)
    ).fetchall()
    
    result = []
    for r in rows:
        d = dict(r)
        if d["ocr_data"]:
            d["ocr_data"] = json.loads(d["ocr_data"])
        result.append(d)
    
    return result


# ── Admin: Get All Documents for Audit ───────────────────────────────────────
@router.get("/admin/audit-log")
async def get_all_documents_audit():
    """Get all documents for admin review with OCR audit data."""
    conn = get_connection()
    rows = conn.execute(
        """SELECT d.*, s.name as student_name 
           FROM documents d 
           JOIN students s ON d.student_id = s.id 
           ORDER BY d.timestamp DESC"""
    ).fetchall()
    
    result = []
    for r in rows:
        d = dict(r)
        if d["ocr_data"]:
            d["ocr_data"] = json.loads(d["ocr_data"])
        result.append(d)
    
    return result


# ── Document Verification ───────────────────────────────────────────────────────
class DocumentVerification(BaseModel):
    status: str  # "verified", "fraud_detected", or "error"
    notes: str = None

@router.post("/verify/{doc_id}")
async def verify_document(doc_id: int, body: DocumentVerification):
    """
    Admin endpoint to verify or flag a document.
    """
    allowed_statuses = ("verified", "fraud_detected", "error")
    if body.status not in allowed_statuses:
        raise HTTPException(status_code=400, detail=f"Status must be one of: {', '.join(allowed_statuses)}")
    
    conn = get_connection()
    row = conn.execute("SELECT id FROM documents WHERE id = ?", (doc_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Document not found.")
    
    conn.execute(
        "UPDATE documents SET verification_status = ?, verification_notes = ? WHERE id = ?",
        (body.status, body.notes, doc_id)
    )
    conn.commit()
    
    return {"message": f"Document {doc_id} marked as {body.status}.", "notes": body.notes}
