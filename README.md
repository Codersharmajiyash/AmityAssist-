# UniAssist

UniAssist is a workflow-centric student service and procedure guidance platform for a university. It is designed as a digital front desk: students can verify their identity, see personalized academic and service information, receive guided withdrawal support, upload documents for mock OCR/fraud checks, file grievances, discover scholarships, and track request status.

The current implementation is a local prototype using FastAPI, SQLite, and a static HTML/CSS/JavaScript frontend. That HTML frontend is only for rapid browser validation of the flows already built. The real kiosk-grade student interface should continue in `frontend_flutter/` as a touch-first Flutter web/tablet app. Docker/PostgreSQL/Redis/MinIO foundation files are also present for the target stack.

## Current Status

Completed baseline:

- Phase 0 project hygiene and setup docs.
- Phase 1 withdrawal intelligence workflow API, checklist generation, official steps, required documents, forms, timelines, and status tracking.
- Phase 2 student/staff backend APIs for profile, notices, exams, backpapers, scholarships, grievances, documents, admin grievance handling, and admin document audit.
- Phase 3 conversational assistant routing for academics, exams, scholarships, grievances, notices, hostel/fees/documents/internships, multilingual hints, voice command markers, and withdrawal refund guidance.
- Prototype frontend alignment for the student dashboard, academics, scholarships, grievances, document upload/OCR result panel, withdrawal status/checklist/steps/forms, dark mode, and Web Speech API controls.
- Flutter kiosk scaffold for login and withdrawal guidance in `frontend_flutter/`.
- Phase 11 staff analytics: lifecycle snapshot, workflow funnel, bottleneck detection, and CSV/PDF report exports.
- Phase 12 multi-campus configuration: campus-scoped procedures, workflow ownership, and cross-campus student lookup.
- Phase 13 deployment foundation: production Compose, Kubernetes manifests, persistent infrastructure, and PostgreSQL migration extensions.
- Phase 14 production hardening: configurable limits, security headers, telemetry, readiness probes, and guarded backup tooling.
- Student Document Center now includes a recent-upload history with verification status and staff notes.

Remaining major work:

- Staff portal frontend.
- Kiosk-grade Flutter/Riverpod frontend for the complete student journey.
- Full JWT/RBAC authentication.
- PostgreSQL/Redis/MinIO runtime migration.
- Production deployment, monitoring, audit hardening, and multi-campus configuration.

## Quick Start

Run from the repository root. If Python is already on PATH:

```powershell
cd C:\Users\HP\ANtiAgentBuilding
pip install -r backend\requirements.txt
python -m uvicorn backend.main:app --host 127.0.0.1 --port 8000 --reload
```

If Python is not on PATH in this Codex machine, use the checked local virtual environment:

```powershell
.\.venv\Scripts\python.exe -m uvicorn backend.main:app --host 127.0.0.1 --port 8000 --reload
```

In another terminal:

```powershell
cd C:\Users\HP\ANtiAgentBuilding\frontend
python -m http.server 5500 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:5500/index.html
```

API docs:

```text
http://127.0.0.1:8000/api/docs
```

Demo student:

```text
Student ID: STU001
```

## Tests

```powershell
.\.venv\Scripts\python.exe -m pytest -q
node --check frontend\js\app.js
```

The current verified result is `61 passed`.

## Main Local Prototype Endpoints

```text
POST /api/auth/verify
POST /api/chat/message
GET  /api/student/profile
GET  /api/student/notices
GET  /api/student/exams
POST /api/student/backpaper
GET  /api/student/scholarships
POST /api/student/scholarships/apply
GET  /api/student/grievances
POST /api/student/grievances
GET  /api/withdrawal/guide
GET  /api/withdrawal/documents
GET  /api/withdrawal/status/{student_id}
POST /api/documents/upload
GET  /api/admin/grievances
POST /api/admin/grievances/{id}/resolve
GET  /api/admin/documents
POST /api/admin/documents/{id}/verify
GET  /api/reports/analytics
GET  /api/reports/funnel
GET  /api/reports/bottlenecks
GET  /api/reports/export?report=analytics&format=csv
GET  /api/campuses
GET  /api/campuses/students?campus_code=NOIDA
GET  /api/campuses/{campus_code}/procedure-rules
PUT  /api/campuses/{campus_code}/procedure-rules/{procedure_type}
GET  /api/health
```

## Target Stack

- Frontend: Flutter/Riverpod for kiosk/tablet/web target, static HTML/CSS/JS for current prototype testing only.
- Backend: FastAPI.
- Database: SQLite locally, PostgreSQL target.
- Cache/session/queue: Redis target.
- File storage: local uploads now, MinIO/S3 target.
- Auth: prototype student verification now, JWT/RBAC target.
- Deployment: Docker Compose foundation included.

## Production deployment

Use the Phase 13 artifacts in [`deploy/`](deploy/README.md). Copy `.env.production.example` to `.env.production`, replace every placeholder, then start the stack with `docker compose --env-file .env.production -f docker-compose.production.yml up --build`.
