"""
Public University Services endpoints for Guest Mode.

Exposes procedure guides, FAQs, contact directories, public notices,
and campus service overviews for students, visitors, parents, and prospective applicants
without requiring login.
"""

from fastapi import APIRouter
from ..database.connection import get_connection

router = APIRouter(prefix="/api/services", tags=["Public Services"])


@router.get("/overview")
async def get_services_overview():
    """Return catalog of public services and procedures."""
    return {
        "services": [
            {
                "id": "withdrawal",
                "title": "Withdrawal Process",
                "category": "Procedures",
                "icon": "exit_to_app",
                "description": "Step-by-step guidance on program withdrawal, required clearances, document checklists, and refund band timelines.",
                "action_label": "View Guide & Roadmap",
                "departments": ["Student Services", "Registrar", "Library", "Hostel", "Finance"],
                "estimated_timeline": "10-15 working days total"
            },
            {
                "id": "scholarships",
                "title": "Scholarships & Financial Aid",
                "category": "Financial Aid",
                "icon": "school",
                "description": "Explore Merit Scholarships (up to 50%), Vice Chancellor's Fellowship (100%), and Sports Excellence waivers.",
                "action_label": "Check Eligibility",
                "departments": ["Scholarship Cell", "Finance Office"],
                "estimated_timeline": "Evaluated every semester"
            },
            {
                "id": "certificates",
                "title": "Certificates & Transcripts",
                "category": "Documentation",
                "icon": "verified",
                "description": "Procedures to request Bonafide Certificates, Character Certificates, Degree Transcripts, and Migration Certificates.",
                "action_label": "Download Forms",
                "departments": ["Registrar Office", "Controller of Examinations"],
                "estimated_timeline": "2-4 working days"
            },
            {
                "id": "hostel",
                "title": "Hostel & Campus Life",
                "category": "Campus Services",
                "icon": "apartment",
                "description": "Hostel room allocation rules, mess schedules, leave & gate pass guidelines, and resident warden contacts.",
                "action_label": "View Hostel Policies",
                "departments": ["Hostel Administration", "Security & Logistics"],
                "estimated_timeline": "Instant policy access"
            },
            {
                "id": "academics",
                "title": "Academic Procedures",
                "category": "Academics",
                "icon": "menu_book",
                "description": "Semester registration, attendance shortage debarment rules, back-paper exam registrations, and result rechecking.",
                "action_label": "View Procedures",
                "departments": ["Academic Affairs", "Examination Cell"],
                "estimated_timeline": "Per academic calendar"
            },
            {
                "id": "notices",
                "title": "University Notices & Bulletins",
                "category": "Announcements",
                "icon": "campaign",
                "description": "Official campus announcements, examination schedules, placement drive notices, and committee open houses.",
                "action_label": "Browse Notices",
                "departments": ["All Campus Departments"],
                "estimated_timeline": "Updated daily"
            },
            {
                "id": "directory",
                "title": "Administrative Contact Directory",
                "category": "Support",
                "icon": "contacts",
                "description": "Direct contact details, office locations, and operating hours for Deans, Registrar, Examination Controller, and Helpdesks.",
                "action_label": "View Contacts",
                "departments": ["Administrative Registry"],
                "estimated_timeline": "Mon-Fri 9:00 AM - 5:00 PM"
            },
            {
                "id": "faqs",
                "title": "Frequently Asked Questions",
                "category": "Helpdesk",
                "icon": "help_outline",
                "description": "Answers to the most common queries regarding admissions, fees, exams, document verification, and lost ID cards.",
                "action_label": "Read FAQs",
                "departments": ["Student Success Center"],
                "estimated_timeline": "Instant search"
            },
            {
                "id": "documents",
                "title": "Document & Forms Repository",
                "category": "Downloads",
                "icon": "file_download",
                "description": "Download 30+ official university application templates, requisitions, no-dues formats, and declaration forms.",
                "action_label": "Access Repository",
                "departments": ["Registrar", "Stores & Logistics", "Finance"],
                "estimated_timeline": "Instant PDF / DOCX download"
            }
        ]
    }


@router.get("/faqs")
async def get_faqs():
    """Return categorized FAQs."""
    return {
        "faqs": [
            {
                "category": "Withdrawal & Refunds",
                "question": "How long does a university withdrawal process take?",
                "answer": "Initial application verification takes 1-2 working days. Department clearances (Library, Hostel, Academic) take 3-5 working days. Once cleared, Finance processes fee adjustments and refunds within 7-10 working days."
            },
            {
                "category": "Withdrawal & Refunds",
                "question": "What documents are required to initiate program withdrawal?",
                "answer": "Mandatory documents include: 1) Filled Withdrawal Application Form, 2) University Student ID proof, 3) Fee clearance statement, 4) Library clearance certificate. If staying in hostel, Hostel clearance is also required. Medical/personal reasons require supporting proof."
            },
            {
                "category": "Scholarships",
                "question": "What is the minimum CGPA required for Merit Scholarship renewal?",
                "answer": "A minimum CGPA of 8.0 is required for the 50% Merit Scholarship. The 100% Vice Chancellor's Fellowship requires a minimum CGPA of 9.0 with zero backpapers."
            },
            {
                "category": "Certificates",
                "question": "How can I obtain a Bonafide Certificate?",
                "answer": "You can download the Bonafide Application form from the Document Repository or use the AI Assistant. Submit the signed form to the Registrar Window (Block A, Ground Floor). Turnaround is 2 working days."
            },
            {
                "category": "Examinations",
                "question": "What is the deadline and fee for Back-Paper registration?",
                "answer": "Back-paper exam registration opens 3 weeks before semester-end examinations. Students can register through their Student Portal under the Academics tab."
            },
            {
                "category": "Hostel",
                "question": "What is the procedure for obtaining a Hostel Clearance during checkout?",
                "answer": "Students must complete room inventory inspection with the Hostel Warden, settle any laundry or mess charges, obtain the signed Hostel Clearance Form, and submit it to the Student Services Desk."
            },
            {
                "category": "General",
                "question": "What should I do if I forgot my student ID card or password?",
                "answer": "You can use this kiosk in Guest Mode to browse services, forms, and talk to the AI Digital Counselor. For ID replacement, download the Student ID Card Form or visit the IT & Registrar helpdesk in Block A."
            }
        ]
    }


@router.get("/directory")
async def get_contact_directory():
    """Return official departmental contacts."""
    return {
        "contacts": [
            {
                "department": "Registrar Office",
                "location": "Block A, Ground Floor, Room 102",
                "email": "registrar@uniassist.edu",
                "phone": "+91 (120) 439-2001",
                "hours": "Mon-Fri: 9:00 AM - 5:00 PM",
                "lead": "Dr. R. K. Sharma (Registrar)"
            },
            {
                "department": "Controller of Examinations",
                "location": "Block B, Second Floor, Room 204",
                "email": "examcell@uniassist.edu",
                "phone": "+91 (120) 439-2015",
                "hours": "Mon-Fri: 9:30 AM - 5:30 PM",
                "lead": "Prof. S. Sengupta (CoE)"
            },
            {
                "department": "Finance & Accounts Desk",
                "location": "Block A, First Floor, Room 115",
                "email": "accounts@uniassist.edu",
                "phone": "+91 (120) 439-2030",
                "hours": "Mon-Fri: 9:00 AM - 4:30 PM",
                "lead": "Mr. Amit Verma (Chief Accounts Officer)"
            },
            {
                "department": "Dean of Student Welfare & Grievance Cell",
                "location": "Block F-3, Ground Floor",
                "email": "dsw@uniassist.edu",
                "phone": "+91 (120) 439-2088",
                "hours": "Mon-Sat: 9:00 AM - 6:00 PM",
                "lead": "Prof. Manisha Kapoor (Dean Student Welfare)"
            },
            {
                "department": "Hostel Administration & Chief Warden",
                "location": "Hostel Block H-1, Admin Wing",
                "email": "hosteladmin@uniassist.edu",
                "phone": "+91 (120) 439-2110",
                "hours": "24/7 Desk Support",
                "lead": "Col. V. P. Singh (Chief Warden)"
            },
            {
                "department": "Central Library Helpdesk",
                "location": "Central Library Building, Level 1",
                "email": "library@uniassist.edu",
                "phone": "+91 (120) 439-2055",
                "hours": "Mon-Sun: 8:00 AM - 10:00 PM",
                "lead": "Mrs. Sunita Rao (Chief Librarian)"
            }
        ]
    }


@router.get("/notices")
async def get_public_notices():
    """Return all public university notices."""
    conn = get_connection()
    rows = conn.execute(
        """SELECT * FROM notices
           WHERE target_branch = 'ALL' AND target_semester = 0
           ORDER BY timestamp DESC"""
    ).fetchall()
    return {"notices": [dict(r) for r in rows]}
