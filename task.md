# Task List — Student Lifecycle Management Platform (AmityAssist)

We will execute the development of AmityAssist in 6 structured phases. We will verify correctness and functionality after each phase.

- `[x]` Phase 1: Database Expansion & Seed Data
    - `[x]` Update database schema in `seed.py` with expanded student profiles, notices, scholarships, exams, internships, grievances, and staff accounts.
    - `[x]` Update seed script with rich seed data matching Amity's courses.
    - `[x]` Verify database initialization and run tests.
- `[x]` Phase 2: Backend API Routes for Student & Staff Operations
    - `[x]` Create `backend/routes/student.py` with profile, exams, backpapers, notices, scholarships, and grievances endpoints.
    - `[x]` Modify `backend/routes/admin.py` to support grievance resolution, document audit logs, and OCR verification.
    - `[x]` Update `backend/routes/documents.py` with mock Document AI OCR & Fraud detection analysis.
    - `[x]` Mount student router in `backend/main.py`.
    - `[x]` Verify endpoints using python testing or pytest.
- `[x]` Phase 3: Conversational AI Router & FSM Enhancements
    - `[x]` Update `backend/services/chat_service.py` to route user intents (academics, scholarships, exams, grievances, withdrawals, help).
    - `[x]` Implement multilingual (Hinglish/Hindi/English) and voice-command routing in the chat logic.
    - `[x]` Add conversational refund calculations for withdrawals.
    - `[x]` Verify chatbot FSM state transitions and test suite.
- `[x]` Phase 4: Modern CSS (Glassmorphism) & Core Dashboard Widgets
    - `[x]` Redesign `frontend/css/styles.css` with a premium glassmorphic system, circular progress rings, animations, and dark mode toggling.
    - `[x]` Update `frontend/index.html` structure with the new widgets: personalized welcome, circular academic progress, fee outstanding, hostel allocation status, and targeted notices.
    - `[x]` Implement client-side theme toggling and tab navigation.
    - `[x]` Verify UI rendering and basic styling.
- `[x]` Phase 5: Student Lifecycle View Modules & Voice AI
    - `[x]` Implement Academics tab (exam results and backpaper registration form).
    - `[x]` Implement Scholarship Hub tab (scheme discovery and one-click application).
    - `[x]` Implement Grievance Desk tab (timeline status tracker).
    - `[x]` Implement Document AI simulation panel (scanning overlay, OCR field results, and fraud warnings).
    - `[x]` Add voice synthesis and transcription (Web Speech API) inside floating widget.
    - `[x]` Verify mock document upload, voice toggle, and forms submittal.
- `[ ]` Phase 6: Multi-Role Staff Portal & E2E Verification
    - `[ ]` Design and implement Staff Portal tab (approval center, grievance responses, and document audit records).
    - `[ ]` Hook up staff portal buttons to backend endpoints.
    - `[ ]` Write automated tests in `backend/tests/` for new endpoints.
    - `[ ]` Run full pytest suite, verify client-server integration, and create walkthrough.
