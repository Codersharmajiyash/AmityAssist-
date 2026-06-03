# AmityAssist

AmityAssist is a student lifecycle management portal for Amity-style university workflows. It combines a FastAPI backend, SQLite seed data, a vanilla HTML/CSS/JS dashboard, student lifecycle modules, document OCR simulation, and a voice-enabled AI advisor.

## Current Status

Completed through Phase 5:

- Expanded student lifecycle database and seed data.
- Student and staff backend routes for profiles, notices, exams, scholarships, grievances, documents, and chat.
- Conversational AI routing for academics, scholarships, exams, grievances, withdrawals, Hinglish/Hindi/English prompts, and refund estimates.
- Glassmorphic student dashboard.
- Student lifecycle view modules:
  - Academics tab with exam results and backpaper registration.
  - Scholarship Hub with scheme discovery and one-click application.
  - Grievance Desk with ticket form and timeline tracker.
  - Document AI panel with scan animation, OCR fields, and fraud warnings.
  - Floating voice widget using the browser Web Speech API.

## Quick Start

Run these commands from:

```powershell
c:\Users\WINDOWS 11\OneDrive\Desktop\AMITYASSIST\AmityAssist-
```

### 1. Install Dependencies

```powershell
pip install -r backend\requirements.txt
```

### 2. Start Backend

```powershell
python -m uvicorn backend.main:app --host 127.0.0.1 --port 8000
```

Backend URL:

```text
http://127.0.0.1:8000
```

API docs:

```text
http://127.0.0.1:8000/api/docs
```

### 3. Start Frontend

Use a localhost frontend server instead of opening the file directly. This is important for browser voice permissions.

```powershell
cd frontend
python -m http.server 5500 --bind 127.0.0.1
```

Open:

```text
http://127.0.0.1:5500/index.html
```

## Login / UI Behavior

The app starts with only the verification screen visible. The sidebar, topbar dashboard shell, module navigation, and voice widget appear only after successful student verification.

Demo login:

```text
Student ID: STU001
```

You can also use seeded institutional email addresses.

## Voice System

The floating voice widget appears after login.

- `Mic`: starts browser speech transcription and sends the transcript to AI Advisor when a session is active.
- `Speak`: reads the latest AI Advisor reply aloud.

Notes:

- Use Chrome or Edge for the best Web Speech API support.
- Microphone access requires browser permission.
- Run the frontend from `http://127.0.0.1:5500/index.html`; raw `file://` pages may block or limit voice behavior.

## Test Suite

Run:

```powershell
python -m pytest
```

Expected current result:

```text
59 passed
```

## Main Endpoints

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
POST /api/documents/upload
GET  /api/health
```

## Project Structure

```text
AmityAssist-/
  backend/
    main.py
    database/
    middleware/
    models/
    routes/
    services/
    tests/
  database/
    chatbot.db
  documentation/
    README.md
  frontend/
    index.html
    css/styles.css
    js/app.js
  task.md
  pytest.ini
```

## Phase 6 Next

Phase 6 is the staff portal and end-to-end verification phase:

- Staff Portal tab.
- Approval center.
- Grievance responses.
- Document audit records.
- Staff portal API actions.
- Full client-server walkthrough.
