# UniAssist — Secure AI-Powered Student Withdrawal Chatbot

A production-quality, full-stack chatbot system for managing student withdrawal requests at an educational institution. Built with FastAPI (Python) and a premium vanilla JS/CSS frontend.

---

## Quick Start

### Prerequisites
- Python 3.10 or higher
- `pip` package manager

### 1. Install Dependencies
```bash
cd c:\Users\HP\ANtiAgentBuilding
pip install -r backend/requirements.txt
```

### 2. Start the Backend Server
```bash
uvicorn backend.main:app --reload
```
Server starts at **http://localhost:8000**  
Interactive API docs: **http://localhost:8000/api/docs**

### 3. Open the Frontend
Open `frontend/index.html` directly in your browser.

### 4. Run the Test Suite
```bash
pytest -v
```

---

## Sample Student Credentials (for testing)

| Student ID | Name             | Email                      | Course                   |
|------------|------------------|----------------------------|--------------------------|
| STU001     | Aisha Malik      | aisha.malik@uni.edu        | Computer Science         |
| STU002     | Rahul Sharma     | rahul.sharma@uni.edu       | Electrical Engineering   |
| STU003     | Priya Nair       | priya.nair@uni.edu         | Business Administration  |
| STU004     | James Osei       | james.osei@uni.edu         | Data Science             |
| STU005     | Fatima Al-Hassan | fatima.alhassan@uni.edu    | Biotechnology            |
| STU006     | Chen Wei         | chen.wei@uni.edu           | Mechanical Engineering   |
| STU007     | Sofia Gonzalez   | sofia.gonzalez@uni.edu     | Psychology               |
| STU008     | Amara Diallo     | amara.diallo@uni.edu       | Architecture             |
| STU009     | Lucas Ferreira   | lucas.ferreira@uni.edu     | Civil Engineering        |
| STU010     | Mei Lin          | mei.lin@uni.edu            | Pharmacy                 |

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Browser                               │
│   frontend/index.html + css/styles.css + js/app.js          │
│   - Verify screen → Chat screen                              │
│   - XSS-safe rendering via escapeHtml()                      │
│   - Session token held in memory only                        │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTP/JSON (localhost:8000)
┌────────────────────▼────────────────────────────────────────┐
│                  FastAPI Backend                              │
│                                                              │
│  POST /api/auth/verify   →  routes/auth.py                   │
│  POST /api/chat/message  →  routes/chat.py                   │
│  GET  /api/health        →  main.py                          │
│                                                              │
│  Middleware stack (applied to every request):                │
│   ├── CORSMiddleware                                         │
│   ├── SecurityHeadersMiddleware (X-Frame, CSP, etc.)         │
│   └── SlowAPI rate limiter (5/min auth, 20/min chat)         │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│               Services Layer                                  │
│                                                              │
│  nlp_service.py   — keyword intent + polarity sentiment      │
│  chat_service.py  — FSM: ASK_REASON→SUGGEST→CONFIRM→DONE    │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│              SQLite Database (database/chatbot.db)            │
│                                                              │
│   students             — pre-seeded, 10 records              │
│   conversations        — every message logged                │
│   withdrawal_requests  — submitted requests                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
ANtiAgentBuilding/
├── backend/
│   ├── main.py                  # FastAPI app entry point
│   ├── requirements.txt
│   ├── database/
│   │   ├── connection.py        # Thread-local SQLite connection
│   │   └── seed.py              # Schema + sample data
│   ├── models/
│   │   └── schemas.py           # Pydantic v2 request/response schemas
│   ├── services/
│   │   ├── nlp_service.py       # Intent classifier + sentiment scorer
│   │   └── chat_service.py      # Conversation FSM
│   ├── routes/
│   │   ├── auth.py              # POST /api/auth/verify
│   │   └── chat.py              # POST /api/chat/message
│   ├── middleware/
│   │   └── security.py          # Security headers middleware
│   └── tests/
│       ├── conftest.py
│       ├── test_auth.py         # 10 tests (2 validation rounds)
│       ├── test_nlp.py          # 12 tests (2 validation rounds)
│       ├── test_chat.py         # 9 tests  (2 validation rounds)
│       └── test_db.py           # 8 tests  (2 validation rounds)
├── frontend/
│   ├── index.html
│   ├── css/styles.css
│   └── js/app.js
├── database/
│   └── chatbot.db               # Auto-created on first run
├── documentation/
│   └── README.md
└── pytest.ini
```

---

## Security Model

| Threat | Mitigation |
|--------|-----------|
| SQL Injection | Parameterised queries (`?` placeholders) throughout; Pydantic whitelist validators |
| XSS | `escapeHtml()` on all user text before DOM insertion; CSP header restricts inline scripts |
| Clickjacking | `X-Frame-Options: DENY` on every response |
| MIME Sniffing | `X-Content-Type-Options: nosniff` |
| Brute Force | SlowAPI rate limiter: 5 req/min on auth, 20 req/min on chat |
| Data Leakage | Identical error message for "not found" and "server error" (prevents enumeration) |
| Session Hijacking | `secrets.token_urlsafe(32)` session tokens; stored in-process memory only |
| Oversized Payloads | Field-level `max_length` enforced both client-side and by Pydantic |

---

## Conversation Flow

```
Student Opens App
      │
      ▼
[Verification Screen]
  Enter ID or Email
      │
      ├─ INVALID → Generic error (no data leak)
      │
      └─ VALID ──▶ [Chat Screen — ASK_REASON]
                        │
                        ▼
                   Student describes reason
                   (NLP classifies intent + sentiment)
                        │
                        ▼
                   [SUGGEST] — Bot offers alternatives
                        │
                        ├─ Student accepts → RESOLVED (session ends)
                        │
                        └─ Student declines ──▶ [CONFIRM]
                                                   │
                              ├─ "CONFIRM" ──▶ Withdrawal created → DONE
                              └─ "CANCEL"  ──▶ Back to ASK_REASON
```

---

## API Reference

### `POST /api/auth/verify`
Verify a student's identity.

**Request:**
```json
{ "student_id": "STU001" }
// or
{ "email": "aisha.malik@uni.edu" }
```

**Response (success):**
```json
{
  "verified": true,
  "session_id": "<secure-token>",
  "student_name": "Aisha Malik",
  "course": "Computer Science",
  "message": "Welcome back, Aisha!"
}
```

---

### `POST /api/chat/message`
Send a message in an active session.

**Request:**
```json
{ "session_id": "<token>", "message": "I cannot afford my fees" }
```

**Response:**
```json
{
  "reply": "💡 We understand financial pressure...",
  "state": "SUGGEST",
  "intent": "financial",
  "sentiment": "negative",
  "withdrawal_submitted": false
}
```
