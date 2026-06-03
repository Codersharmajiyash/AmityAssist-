from fastapi import APIRouter, HTTPException
from ..database.connection import get_connection

router = APIRouter(prefix="/api/status", tags=["Status"])

@router.get("/{student_id}")
async def get_status(student_id: str):
    conn = get_connection()
    try:
        row = conn.execute(
            "SELECT status, timestamp, reason FROM withdrawal_requests WHERE student_id = ? ORDER BY timestamp DESC LIMIT 1",
            (student_id.upper().strip(),)
        ).fetchone()
        
        if not row:
            return {"has_request": False}
            
        return {
            "has_request": True,
            "status": row["status"],
            "timestamp": row["timestamp"],
            "reason": row["reason"]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail="Database error while fetching status.")
