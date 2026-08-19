"""
Official forms and documents catalog endpoint.

Exposes university forms, requisitions, applications, and procedures
for students, faculty, and administrative staff with category filtering
and search support.
"""

from typing import Optional
from fastapi import APIRouter, Query
from ..database.connection import get_connection

router = APIRouter(prefix="/api/forms", tags=["Forms Catalog"])


@router.get("/catalog")
async def get_forms_catalog(
    category: Optional[str] = Query(None, description="Filter by category (e.g. Academics, Finance, HR)"),
    department: Optional[str] = Query(None, description="Filter by department"),
    q: Optional[str] = Query(None, description="Search query across form title, description, or department")
):
    """
    Get all official downloadable university forms and documents.
    """
    conn = get_connection()
    sql = "SELECT id, form_key, name, category, department, description, file_name, download_url, file_type FROM forms_catalog WHERE 1=1"
    params = []

    if category:
        sql += " AND LOWER(category) = LOWER(?)"
        params.append(category.strip())

    if department:
        sql += " AND LOWER(department) LIKE LOWER(?)"
        params.append(f"%{department.strip()}%")

    if q:
        sql += " AND (LOWER(name) LIKE LOWER(?) OR LOWER(description) LIKE LOWER(?) OR LOWER(category) LIKE LOWER(?) OR LOWER(department) LIKE LOWER(?))"
        term = f"%{q.strip()}%"
        params.extend([term, term, term, term])

    sql += " ORDER BY category ASC, id ASC"

    rows = conn.execute(sql, params).fetchall()
    forms = [dict(row) for row in rows]

    return {
        "count": len(forms),
        "forms": forms
    }


@router.get("/categories")
async def get_form_categories():
    """
    Get list of all form categories with document counts.
    """
    conn = get_connection()
    rows = conn.execute(
        """SELECT category, COUNT(*) as count 
           FROM forms_catalog 
           GROUP BY category 
           ORDER BY count DESC"""
    ).fetchall()
    
    return {
        "categories": [dict(row) for row in rows]
    }
