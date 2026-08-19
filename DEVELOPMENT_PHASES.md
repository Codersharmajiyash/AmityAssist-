# UniAssist Development Phases

This file is the teammate handoff for the current UniAssist build. It maps the CampusAssist PDFs into the local repository state and gives the next implementation order.

## Product Definition

UniAssist is a student service and procedure guidance platform. It is not only a chatbot. The assistant is one interface over structured university services:

- official procedure guidance
- student dashboard
- workflow tracking
- document intelligence
- grievance management
- notice intelligence
- scholarship and academics support
- staff/admin processing
- kiosk/tablet student access, voice assistance, analytics, and multi-campus configuration

## Frontend Direction

The static `frontend/` app is a validation prototype. It exists so the team can run Phase 0-3 flows immediately in a browser, test backend endpoints, and demo student journeys without waiting for Flutter tooling.

The intended production/kiosk interface is `frontend_flutter/`. Build kiosk work there:

- touch-first layout for lobby tablets and kiosk screens
- large controls and readable typography
- minimal typing, with guided choices wherever possible
- session reset after completion or inactivity
- privacy-aware screens that avoid exposing another student's data
- withdrawal forms prepared for download, print, or staff handoff
- voice support where the host browser/device allows it

Do not treat the HTML dashboard as the final kiosk experience.

## Phase 0 - Project Foundation And Hygiene

Goal: make the project clean, runnable, and safe to hand to teammates.

Completed:

- Root README with quick start, tests, endpoints, and target stack.
- `.gitignore` for Python caches, local DB files, uploads, temporary PDF extracts, env files, test captures, Node/Flutter build outputs, and editor files.
- Existing Docker Compose foundation for API, PostgreSQL, Redis, and MinIO.
- Existing backend configuration via `backend/config.py`.
- Local virtual environment `.venv` created and requirements installed for this machine.

Important notes:

- Runtime still uses SQLite for local prototype behavior.
- PostgreSQL, Redis, S3/MinIO, JWT, and RBAC are present as target-stack scaffolding, not full production runtime.
- Keep uploaded documents and local database files out of GitHub.
- This repository currently tracks some generated `__pycache__` and SQLite WAL/SHM files. Remove them from Git tracking before the team pushes a clean production branch.

## Phase 1 - Withdrawal Intelligence MVP

Goal: move withdrawal from chatbot-only behavior into structured procedure guidance.

Completed backend pieces:

- `GET /api/withdrawal/guide`
- `GET /api/withdrawal/documents`
- `GET /api/withdrawal/status/{student_id}`
- Procedure steps seeded in SQLite.
- Procedure documents seeded in SQLite.
- Procedure forms seeded in SQLite.
- Withdrawal request reference generation.
- Checklist generation when withdrawal is confirmed.
- Workflow event creation.
- Audit event recording for withdrawal submission.

Frontend support:

- Request Status screen renders active request details.
- Checklist panel renders required documents.
- Official procedure panel renders steps, departments, and timelines.
- Forms panel renders configured withdrawal forms.

Remaining Phase 1 hardening:

- Add staff actions to advance withdrawal statuses.
- Link uploaded documents to withdrawal checklist items.
- Add more official policy text for refund and withdrawal rules.

## Phase 2 - Core Student And Staff APIs

Goal: expose student lifecycle data and staff processing APIs.

Completed:

- Student profile endpoint.
- Personalized notices endpoint.
- Exams endpoint.
- Backpaper registration endpoint.
- Scholarship discovery and application endpoints.
- Student grievance create/list endpoints.
- Internship endpoint.
- Document upload endpoint with mock OCR/fraud analysis.
- Admin grievance list/detail/resolve endpoints.
- Admin document audit and verification endpoints.
- Admin statistics endpoint.

Frontend support:

- Dashboard uses profile data from verification response.
- Dashboard loads targeted notices.
- Academics tab loads exams and supports backpaper registration.
- Scholarship tab loads schemes and supports one-click application.
- Grievance tab files grievances and renders timeline.
- Document Center uploads files and displays OCR/fraud results.

Remaining Phase 2 hardening:

- Add frontend handling for duplicate scholarship applications.
- Add document list/history for the current student.
- Normalize response shapes for all endpoints.

## Phase 3 - Conversational AI Router And FSM Enhancements

Goal: make the assistant route student messages to lifecycle capabilities while preserving withdrawal FSM behavior.

Completed:

- Intent routing for academics, scholarships, exams, grievances, withdrawals, notices, fees, hostel, documents, internships, help, and unknown.
- Hindi/Hinglish/English signal detection.
- Voice command marker detection.
- CGPA/attendance response.
- Scholarship eligibility response and conversational apply support.
- Exam/backpaper summary and conversational registration support.
- Grievance conversational filing flow.
- Notice, hostel, fee, document, and internship responses.
- Withdrawal refund policy band guidance.
- Existing withdrawal confirmation flow preserved.

Frontend support:

- HTML prototype AI Advisor tab sends chat messages.
- Quick replies support withdrawal states.
- Voice widget can transcribe and read latest bot reply when browser support is available.
- Flutter kiosk scaffold exists for the target interface, currently covering login and withdrawal guidance.

Remaining Phase 3 hardening:

- Replace deterministic keyword routing with a more maintainable rules table or config.
- Add richer multilingual response templates.
- Add tests for every frontend-visible lifecycle chat path.

## Phase 15 - Flutter Mobile App / Kiosk UI

Goal: Expand `frontend_flutter/` into a full touch-first kiosk interface with offline caching and session resets.

Completed:
- `KioskDashboard` created with touch-first layout.
- `SessionManager` widget built to handle idle session timeouts (resets after 2 mins inactivity).
- `HiveService` configured for local NoSQL data caching of notices and profiles.
- Integrated Kiosk routing in `uniassist_app.dart` to serve the kiosk dashboard upon login.

## Phase 16 - Staff Portal Frontend Expansion

Goal: Build a dedicated desktop admin client inside the Flutter app for clearance queues, approvals, and grievances.

Completed:
- `StaffDesktopLayout` implemented providing a responsive split-view sidebar.
- `ClearanceQueueScreen` built with a data table for pending student withdrawals.
- `DocumentApprovalsScreen` built for batch document review alongside Document AI OCR results.
- `GrievanceResponseScreen` built for staff to read and resolve grievances.
- `ShellRoute` implemented in `go_router` to securely wrap all `/staff` paths in the desktop layout.

## Phase 17 - Native iOS/Android Features

Goal: Add mobile biometric authentication, hardware push notifications, and local offline store sync.

Completed:
- Added `local_auth`, `flutter_local_notifications`, `connectivity_plus`, `hive`, and `hive_flutter` dependencies.
- `BiometricLogin` integrated into `LoginScreen` allowing Face ID / Fingerprint unlocks.
- `NotificationService` configured for local push notification channels (prototype).
- `SyncService` created to listen for network state changes and trigger background syncs to resolve offline actions.

## Immediate Next Phase

The next chunk is to finish wiring the backend endpoints to these new frontend UI components (e.g., swapping static data in `ClearanceQueueScreen` with API calls).
