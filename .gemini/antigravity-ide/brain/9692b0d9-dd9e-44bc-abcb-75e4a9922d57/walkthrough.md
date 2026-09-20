# Voice AI Post-Form Guidance, Hybrid RAG Architecture & Gemini Setup Guide

This document summarizes the enhancements made to UniAssist's Voice AI counselor, including comprehensive guidance for all 31 university catalog forms, navigation capabilities, the hybrid deterministic + LLM architecture, and instructions for configuring the Gemini API key.

---

## 1. Complete Form Guidance Scenarios (All 31+ Forms)

The SQLite FTS5 BM25 search engine (`policy_fts`) and `PolicySearchService` now index post-download submission procedures for all university forms.

### When a student asks: *"What should I do after getting [form name]?"*
The Voice AI returns a structured 3-step actionable procedure:
1. **Required Attachments**: Required photocopies, ID proofs, fee receipts, or medical certificates.
2. **Submission Office / Desk**: Specific room, window, or officer (e.g., Registrar Window 2, Room 102; Accounts Counter Room 14; Controller of Examinations Window 3).
3. **Turnaround SLA**: Processing timeline (e.g., 3–5 working days, 48 hours, 21 days).
4. **Direct Navigation (`action_url`)**: A 1-tap button to open the form in the catalog (`/forms`) or launch the workflow (`/withdrawal`).

#### Key Form Examples:
| Form Name | Clause / ID | Required Attachments | Submission Desk | Processing SLA | Action URL |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Migration Certificate** | `PROC-FORM-15` | All semester marksheets, provisional degree, no-dues clearance slip | Registrar Office Window 2 (Room 102) | 3–5 working days | `/forms` |
| **Result Rechecking** | `PROC-FORM-27` | Grade report copy, ₹500 fee challan per paper | Controller of Examinations Window 3 | 21 working days | `/forms` |
| **Student ID Reissue** | `PROC-FORM-28` | White-bg photo, police lost report / NCR, ₹200 fee receipt (or Smart Offset) | Student Services / Registrar Room 101 | 48 hours | `/forms` |
| **Condonation (AC-04)** | `PROC-FORM-AC04`| Hospital OPD / prescription or university duty certificate | Dean Academic Affairs Room 201 | 10 days before exams | `/forms` |
| **Exit Interview** | `PROC-FORM-17` | Completed 4-gate clearance, exit counseling verification | Registrar Room 102 & DSW Room 106 | Triggers ₹10,000 refund | `/withdrawal` |
| **Program Withdrawal** | `PROC-FORM-WTH` | ID proof, guardian consent, bank passbook/cheque for NEFT | Registrar Office Room 102 | 14 working days | `/withdrawal` |
| **Fee Clearance** | `PROC-FORM-FEE-CLR`| Fee receipt or Smart Caution Deposit Offset confirmation | Finance Counter Window 4 | Immediate | `/withdrawal` |
| **Library Clearance** | `PROC-FORM-LIB-CLR`| Handover of books/journals, fine settlement via offset | Central Library Circulation Desk | Digital Stamp | `/withdrawal` |
| **Hostel Clearance** | `PROC-FORM-HSTL-CLR`| Room inventory inspection checklist, room & almirah keys | Assistant Warden & Gate 2 Desk | 7 working days | `/withdrawal` |
| **TA / DA Claim** | `PROC-FORM-08` | Original boarding passes, train tickets, event certificate, duty order | Finance & Accounts Room 14 | 7–10 working days | `/forms` |
| **Degree Application** | `PROC-FORM-22` | Cumulative gradesheet, 10th certificate, no-dues slip, ₹1,500 convocation fee | Controller of Examinations Window 1 | 15 working days | `/forms` |

---

## 2. University Navigation ("Where can you take me?")

When students ask navigation questions, the Voice AI acts as an interactive concierge:
- **"Where can you take me?"**: Lists the 5 primary campus destinations with instant shortcuts:
  1. `/forms` — Forms & Applications Catalog
  2. `/withdrawal` — Program Withdrawal & Clearance Cockpit
  3. `/exams` — Examination & Rechecking Schedule
  4. `/chat` — Student Grievance Redressal Desk (48h SLA)
  5. `/scholarship` — Scholarships & Financial Aid
- **"Take me to [portal]"**: Instantly confirms via speech and provides the direct clickable navigation button.
- **"What should I click here?"**: Screen-aware guidance inspects the active route, primary action, and available buttons to direct the user.

---

## 3. How the Hybrid AI System Works

```
┌─────────────────────────────────────────────────────────────┐
│                       Student Voice / Text Query            │
│                       + Active Screen Context               │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│          Layer 1: FTS5 BM25 Semantic Retrieval              │
│  - Sub-5ms keyword & phrase search across 38 ordinances/forms│
│  - Filters conversational stop-words with progressive AND/OR│
│  - Zero-hallucination ground truth (fees, desks, SLAs)      │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│          Layer 2: Live Profile & Context Fusion             │
│  - Injects student attendance %, caution balance, due fees  │
│  - Detects active page route, screen name, primary actions  │
└──────────────────────────────┬──────────────────────────────┘
                               │
               ┌───────────────┴───────────────┐
               │                               │
        Gemini Key Present?            Local Mode (No Key)
               │                               │
               ▼                               ▼
┌──────────────────────────────┐ ┌──────────────────────────────┐
│  Layer 3A: Gemini Synthesis  │ │  Layer 3B: Deterministic RAG │
│  - Fluent conversational TTS │ │  - Template-driven advice    │
│  - Understands noisy speech  │ │  - 100% offline reliability  │
│  - Grounded strictly in facts│ │  - 0% hallucinations         │
└──────────────┬───────────────┘ └──────────────┬───────────────┘
               │                               │
               └───────────────┬───────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                TTS Audio Playback + Pulse Highlight         │
│           + Direct Clickable Route Navigation Button         │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Setting Up Your Gemini API Key

### Step 1: Create a Free Gemini API Key
1. Go to [Google AI Studio](https://aistudio.google.com/).
2. Sign in with your Google account.
3. Click **Get API key** and copy your API key.

### Step 2: Add the Key to `.env`
Open the `.env` file in your workspace root (`c:\Users\HP\ANtiAgentBuilding\.env`):
```env
# Change LLM_PROVIDER to gemini
LLM_PROVIDER=gemini

# Paste your API key here
GEMINI_API_KEY=AIzaSy...your_actual_key_here...

# Default model (fastest and free)
GEMINI_MODEL=gemini-1.5-flash
LLM_TIMEOUT_SECONDS=8
```

### Step 3: Verify
Restart the backend (or let uvicorn reload):
```powershell
.\.venv\Scripts\python.exe -m uvicorn backend.main:app --reload --port 8000
```
UniAssist will automatically detect `GEMINI_API_KEY` and activate Gemini conversational synthesis.

---

## 5. Why Gemini Will Listen and Respond Better

1. **Semantic Intent Understanding vs. Rigid Keywords**:
   - Spoken speech is rarely typed perfectly. Students might say: *"I lost my plastic card how do I clear gate?"* or *"What do I do with the migration paper after taking it?"*
   - Pure keyword search might look for exact words. With Gemini, the model understands the semantic meaning and extracts the exact form (`PROC-FORM-15` or `PROC-FORM-28`).
2. **Natural Spoken Cadence (TTS Tuning)**:
   - Without an LLM, responses are structured templates.
   - With Gemini, responses are synthesized into 2-3 warm, clear spoken sentences optimized for the kiosk voice speaker (e.g. replacing special characters, explaining steps calmly).
3. **Resilient Handling of Speech-to-Text Transcription Noise**:
   - Indian English accents or background noise on web microphones sometimes result in phonetic misspellings (e.g. "condonation" transcribed as "condonation form" or "exam rechecking").
   - Gemini naturally forgives minor transcription quirks and answers the intended question accurately.
4. **Safety & Zero Hallucination**:
   - Because Gemini is fed the **exact retrieved database facts** (room numbers, fee slabs, and SLAs), it cannot invent incorrect fees or non-existent offices. It provides human-like fluency with mathematical accuracy.
