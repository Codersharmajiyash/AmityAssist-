# 🏛️ UniAssist Generalization & Institutional Setup Guide
## Complete Technical Specification, Architecture, and Step-by-Step Implementation Manual

> **Purpose**: This document specifies the complete engineering blueprint for converting UniAssist from a single-institution platform into a **fully generalized, white-label, multi-tenant University Operating System and Kiosk Platform**. Any higher-education institution (central, state, private, engineering, medical, or distance-learning) can adopt, brand, configure, and customize this platform with **zero source code modifications**.

---

## 📑 Table of Contents
1. [Architectural Overview & Core Tenets](#1-architectural-overview--core-tenets)
2. [Database Schemas & Persistence Contracts](#2-database-schemas--persistence-contracts)
3. [Module 1: Dynamic White-Label Branding Engine](#3-module-1-dynamic-white-label-branding-engine)
4. [Module 2: Feature & Tab Switchboard (Dynamic Module Enablement)](#4-module-2-feature--tab-switchboard-dynamic-module-enablement)
5. [Module 3: Procedure Step Customizer (Workflow Engine)](#5-module-3-procedure-step-customizer-workflow-engine)
6. [Module 4: Dynamic Clearance Pipeline & Financial Sync](#6-module-4-dynamic-clearance-pipeline--financial-sync)
7. [Module 5: Dynamic Document & Policy RAG Ingestion](#7-module-5-dynamic-document--policy-rag-ingestion)
8. [Backend API Specification (Complete Endpoint Matrix)](#8-backend-api-specification-complete-endpoint-matrix)
9. [Frontend Client Integration (Flutter & Web)](#9-frontend-client-integration-flutter--web)
10. [Step-by-Step Onboarding Execution Walkthrough](#10-step-by-step-onboarding-execution-walkthrough)
11. [Data Integrity, Concurrency & Backward Compatibility Safeguards](#11-data-integrity-concurrency--backward-compatibility-safeguards)
12. [Developer Implementation Checklist](#12-developer-implementation-checklist)

---

## 1. Architectural Overview & Core Tenets

```
                             ┌────────────────────────────────────────────────────────┐
                             │               UniAssist Neutral Platform               │
                             │        (FastAPI Backend + Flutter Kiosk / Web)         │
                             └───────────────────────────┬────────────────────────────┘
                                                         │
                                        Fetches Tenant Contract on Boot
                                                         │
                                 ┌───────────────────────┴───────────────────────┐
                                 ▼                                               ▼
     ┌───────────────────────────────────────────────────────┐     ┌───────────────────────────────────────────────────────┐
     │           Institution A: Central University           │     │            Institution B: Commuter College            │
     ├───────────────────────────────────────────────────────┤     ├───────────────────────────────────────────────────────┤
     │ • Branding: Maroon & Gold, Crest Logo                 │     │ • Branding: Teal & Navy, Modern Monogram              │
     │ • Active Modules: All 8 Modules Active                │     │ • Active Modules: Hostel & Mess OFF, Scholarships OFF │
     │ • Withdrawal Procedure: 11 Steps (Hostel Included)    │     │ • Withdrawal Procedure: 8 Steps (Hostel Removed)      │
     │ • Clearance Gates: 4 Gates (Lib, Host, Acc, Reg)      │     │ • Clearance Gates: 3 Gates (Lib, Lab, Acc, Reg)       │
     │ • Refund Slabs: Central UGC Standard (15/30/60 Days)  │     │ • Refund Slabs: State Council Policy (10/20/45 Days)  │
     └───────────────────────────────────────────────────────┘     └───────────────────────────────────────────────────────┘
```

### Core Tenets:
1. **Zero Code Changes for New Deployments**: All institution-specific parameters (names, colors, logos, tabs, procedure steps, clearance gates, refund slabs) reside in database tables and configuration contracts, never in hardcoded UI strings.
2. **Dual-Control Principle**: Developers retain 100% source-code access via Git, while non-technical university administrators (Registrars, Deans) manage their institution through the Web/Kiosk Admin Setup UI.
3. **Instant Hot-Reloading**: Alterations made in the Admin Setup UI take effect immediately in student sessions without restarting backend services or recompiling client applications.
4. **Immutable Historical Auditability**: Any administrative modification to workflows, feature flags, or clearance steps is logged in tamper-evident audit tables with the actor ID, timestamp, and previous state.

---

## 2. Database Schemas & Persistence Contracts

The generalized architecture relies on four dedicated relational tables in SQLite (and PostgreSQL in production):

### 2.1. `institution_config` Table
Stores generic key-value configuration for branding, contact windows, and active feature sets.
```sql
CREATE TABLE IF NOT EXISTS institution_config (
    key             TEXT PRIMARY KEY,
    value           TEXT NOT NULL,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### Key Catalog:
* `institution_name`: Full university name (e.g. `"Delhi Technological University"`).
* `short_name`: Acronym used for reference numbers and badges (e.g. `"DTU"`).
* `institution_motto`: Official university motto.
* `crest_logo_url`: URL or local static asset path to the university crest/seal.
* `primary_color`: Hex color code for primary buttons and app bars (e.g. `"#800000"`).
* `secondary_color`: Hex color code for accents and highlights (e.g. `"#D4AF37"`).
* `contact_email`: Official administrative support email.
* `contact_phone`: Registrar helpline number.
* `address`: Physical campus address displayed on receipts and PDFs.
* `enabled_modules`: JSON serialized dictionary of feature toggles.

### 2.2. `procedure_steps` Table
Stores the ordered sequence of informational and operational steps for university procedures (e.g., `'withdrawal'`).
```sql
CREATE TABLE IF NOT EXISTS procedure_steps (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    procedure_code  TEXT NOT NULL,
    step_number     INTEGER NOT NULL,
    title           TEXT NOT NULL,
    description     TEXT,
    department      TEXT NOT NULL,
    timeline_text   TEXT NOT NULL,
    status_after    TEXT DEFAULT 'documents_pending',
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(procedure_code, step_number)
);
```

### 2.3. `institution_clearance_chain` Table
Stores the physical clearance gates that students must pass sequentially.
```sql
CREATE TABLE IF NOT EXISTS institution_clearance_chain (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    desk_code       TEXT NOT NULL UNIQUE,
    desk_name       TEXT NOT NULL,
    sequence_order  INTEGER NOT NULL,
    is_active       INTEGER NOT NULL DEFAULT 1,
    description     TEXT
);
```

### 2.4. `institution_refund_slabs` Table
Stores the financial fee refund rules based on calendar day thresholds relative to admission closure.
```sql
CREATE TABLE IF NOT EXISTS institution_refund_slabs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    slab_label      TEXT NOT NULL UNIQUE,
    min_days        INTEGER NOT NULL,
    max_days        INTEGER NOT NULL,
    refund_percent  REAL NOT NULL,
    policy_note     TEXT
);
```

---

## 3. Module 1: Dynamic White-Label Branding Engine

### Operational Flow:
1. **Initial Boot**:
   * When the Flutter App or Web Frontend loads, it immediately fires `GET /api/institution/config`.
2. **Dynamic Token Propagation**:
   * The client updates its global theme with the returned `primary_color` and `secondary_color`.
   * The `AppBar` title renders `institution_name`.
   * All logo placeholders load `crest_logo_url`.
3. **Reference Prefix Generation**:
   * Dynamic reference numbers replace static prefixes:
     ```python
     def generate_reference() -> str:
         short_name = InstitutionService.get_config().get("short_name", "UNI").upper()
         year = datetime.now().year
         suffix = secrets.token_hex(2).upper()
         return f"{short_name}-WTH-{year}-{suffix}"
     ```

---

## 4. Module 2: Feature & Tab Switchboard (Dynamic Module Enablement)

The Switchboard allows administrators to activate or deactivate modules across the platform based on the university's operating model.

### 4.1. Module Manifest Specification
The feature dictionary supports the following canonical module identifiers:

```json
{
  "dashboard": true,
  "academics": true,
  "withdrawal": true,
  "forms": true,
  "grievance": true,
  "scholarships": false,
  "hostel": false,
  "examinations": true,
  "voice_ai": true,
  "documents": true
}
```

### 4.2. Impact Matrix when a Module is Toggled OFF:

| Target Component | Behavior when Module is Disabled (`false`) |
| :--- | :--- |
| **Sidebar Navigation (Web)** | Element `<a id="nav-[module]">` receives the `hidden` attribute. |
| **Flutter Navigation Drawer** | The corresponding `NavigationDrawerDestination` is omitted from the widget tree. |
| **Student Dashboard** | Summary cards or status badges for that module are skipped; grid automatically reflows. |
| **Client Routing** | Directly navigating to the route renders an informative banner: *"This service is disabled by your institution."* |
| **Conversational AI** | The AI assistant excludes the module from available destination prompts and navigation commands. |
| **API Endpoints** | Requests to disabled module endpoints return HTTP `403 Forbidden` (`{"detail": "Module [module] is disabled for this tenant"}`). |

---

## 5. Module 3: Procedure Step Customizer (Workflow Engine)

Administrators can customize any university workflow (such as the default Program Withdrawal flow) directly through the Admin UI.

### 5.1. Atomic Operations Supported:

#### Action A: Deleting an Unwanted Step
* **Scenario**: A commuter day-scholar college removes *"Hostel & Mess Clearance"*.
* **Database Action**:
  ```sql
  BEGIN TRANSACTION;
  -- 1. Remove the target step
  DELETE FROM procedure_steps 
  WHERE procedure_code = 'withdrawal' AND step_number = :target_step;

  -- 2. Decrement step numbers for all subsequent steps to maintain continuous indexing
  UPDATE procedure_steps 
  SET step_number = step_number - 1, updated_at = CURRENT_TIMESTAMP
  WHERE procedure_code = 'withdrawal' AND step_number > :target_step;
  COMMIT;
  ```

#### Action B: Editing an Existing Step
* **Scenario**: Shortening the Accounts clearance SLA from 7 days to 48 hours and updating room details.
* **Database Action**:
  ```sql
  UPDATE procedure_steps 
  SET title = :title, 
      description = :description, 
      department = :department, 
      timeline_text = :timeline_text, 
      updated_at = CURRENT_TIMESTAMP
  WHERE procedure_code = 'withdrawal' AND step_number = :step_number;
  ```

#### Action C: Injecting a New Step
* **Scenario**: An engineering institute adds *"Laboratory Equipment & Toolkit Handover"* at position 3.
* **Database Action**:
  ```sql
  BEGIN TRANSACTION;
  -- 1. Shift existing steps from insertion index upwards
  UPDATE procedure_steps 
  SET step_number = step_number + 1 
  WHERE procedure_code = 'withdrawal' AND step_number >= :insert_at_step;

  -- 2. Insert new step record
  INSERT INTO procedure_steps 
  (procedure_code, step_number, title, description, department, timeline_text, status_after)
  VALUES ('withdrawal', :insert_at_step, :title, :description, :department, :timeline_text, 'documents_pending');
  COMMIT;
  ```

#### Action D: Drag-and-Drop Reordering
* **Scenario**: Moving Departmental Review ahead of Central Library Clearance.
* **Database Action**: Accepts an ordered array of step IDs `[id_3, id_1, id_2, id_4]` and updates `step_number = index + 1` within an atomic transaction.

---

## 6. Module 4: Dynamic Clearance Pipeline & Financial Sync

The procedure steps must remain synchronized with the physical clearance gates in the database.

### 6.1. Dynamic Gate Initialization
In `backend/services/withdrawal_workflow.py`, `create_withdrawal_request()` must not use a static list. Instead, it reads the active clearance chain:

```python
def create_withdrawal_request(student_id: str, reason: str, intent: str) -> str:
    _ensure_clearance_tables()
    conn = get_connection()
    reference = generate_reference()
    
    # Query active clearance desks dynamically
    active_desks = conn.execute(
        """SELECT desk_code, sequence_order 
           FROM institution_clearance_chain 
           WHERE is_active = 1 
           ORDER BY sequence_order ASC"""
    ).fetchall()

    # Fallback to default if no custom chain exists
    if not active_desks:
        active_desks = [
            {"desk_code": "LIBRARY", "sequence_order": 1},
            {"desk_code": "HOSTEL", "sequence_order": 2},
            {"desk_code": "ACCOUNTS", "sequence_order": 3},
            {"desk_code": "REGISTRAR", "sequence_order": 4},
        ]

    for desk in active_desks:
        conn.execute(
            """INSERT INTO clearance_gates
               (reference_no, department, sequence_order, status, dues_amount)
               VALUES (?, ?, ?, 'PENDING', 0.0)""",
            (reference, desk["desk_code"], desk["sequence_order"]),
        )
```

---

## 7. Module 5: Dynamic Document & Policy RAG Ingestion

Instead of manually inserting SQL rows for ordinances and forms:

1. **Upload Endpoint (`POST /api/documents/ingest-handbook`)**:
   * Accepts university ordinance handbooks in PDF or DOCX format.
2. **Automated Clause Segmentation**:
   * Python parser (`pypdf` / `python-docx`) extracts text chunks using regex patterns matching Ordinance headers (e.g. `ORD-ACAD-\d+`, `Article \d+`, `Clause \d+\.\d+`).
3. **SQLite FTS5 Full-Text Search Populator**:
   * Records are indexed into `policies_fts` with BM25 weights.
4. **Voice RAG Grounding**:
   * `PolicySearchService.hybrid_guidance()` queries the FTS5 index, ensuring the AI assistant answers with citations from the uploaded handbook.

---

## 8. Backend API Specification (Complete Endpoint Matrix)

### 8.1. Institution Branding & Configuration
* **`GET /api/institution/config`**
  * **Response**: `200 OK`
  ```json
  {
    "institution_name": "Delhi Technological University",
    "short_name": "DTU",
    "crest_logo_url": "/static/branding/dtu_crest.png",
    "primary_color": "#800000",
    "secondary_color": "#D4AF37",
    "contact_email": "registrar@dtu.ac.in",
    "contact_phone": "+91-11-27871018",
    "website_url": "http://dtu.ac.in",
    "address": "Shahbad Daulatpur, Bawana Road, Delhi - 110042"
  }
  ```
* **`PUT /api/institution/config`**
  * **Payload**:
  ```json
  {
    "updates": {
      "institution_name": "Indian Institute of Technology Delhi",
      "short_name": "IITD"
    }
  }
  ```

### 8.2. Feature & Tab Switchboard
* **`GET /api/institution/modules`**
  * **Response**: `200 OK`
  ```json
  {
    "status": "success",
    "modules": {
      "dashboard": true,
      "academics": true,
      "withdrawal": true,
      "forms": true,
      "grievance": true,
      "scholarships": false,
      "hostel": false,
      "examinations": true,
      "voice_ai": true
    }
  }
  ```
* **`PUT /api/institution/modules`**
  * **Payload**:
  ```json
  {
    "modules": {
      "scholarships": false,
      "hostel": false
    }
  }
  ```

### 8.3. Procedure Step Customizer
* **`GET /api/procedures/{code}/steps`**
  * **Response**: `200 OK`
  ```json
  {
    "procedure_code": "withdrawal",
    "total_steps": 10,
    "steps": [
      {
        "id": 1,
        "step_number": 1,
        "title": "Collect withdrawal reason",
        "description": "Record official reason and required supporting docs.",
        "department": "Student Services Desk",
        "timeline_text": "Immediate during initiation."
      }
    ]
  }
  ```
* **`POST /api/procedures/{code}/steps`**
  * **Payload**:
  ```json
  {
    "insert_at_step": 3,
    "title": "Laboratory Equipment Return",
    "description": "Hand over component kits and toolboxes.",
    "department": "Department Laboratory In-Charge",
    "timeline_text": "1 working day"
  }
  ```
* **`PUT /api/procedures/{code}/steps/{step_number}`**
  * **Payload**:
  ```json
  {
    "title": "Bursar & Accounts Office Clearance",
    "description": "Verify fee dues and calculate UGC refund percentage.",
    "department": "Bursar Office",
    "timeline_text": "48 hours guaranteed"
  }
  ```
* **`DELETE /api/procedures/{code}/steps/{step_number}`**
  * **Response**: `200 OK` (`{"success": true, "deleted_step": 4, "remaining_steps": 9}`)
* **`POST /api/procedures/{code}/steps/reorder`**
  * **Payload**: `{"ordered_step_ids": [1, 3, 2, 4, 5]}`

---

## 9. Frontend Client Integration (Flutter & Web)

### 9.1. Flutter Riverpod Architecture

#### Provider Definitions:
1. `institutionConfigProvider`: FutureProvider querying `GET /api/institution/config`.
2. `enabledModulesProvider`: StateNotifierProvider querying `GET /api/institution/modules`.
3. `procedureStepsProvider(code)`: FutureProvider querying `GET /api/procedures/{code}/steps`.

#### Conditional Navigation Drawer:
```dart
class UniAssistDrawer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(enabledModulesProvider).asData?.value ?? {};

    return NavigationDrawer(
      children: [
        NavigationDrawerDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
        if (modules['academics'] ?? true)
          NavigationDrawerDestination(icon: Icon(Icons.school), label: Text('Academics')),
        if (modules['scholarships'] ?? true)
          NavigationDrawerDestination(icon: Icon(Icons.monetization_on), label: Text('Scholarships')),
        if (modules['grievance'] ?? true)
          NavigationDrawerDestination(icon: Icon(Icons.support_agent), label: Text('Grievance Desk')),
        if (modules['withdrawal'] ?? true)
          NavigationDrawerDestination(icon: Icon(Icons.exit_to_app), label: Text('Withdrawal')),
        if (modules['forms'] ?? true)
          NavigationDrawerDestination(icon: Icon(Icons.folder_shared), label: Text('Forms Hub')),
      ],
    );
  }
}
```

### 9.2. Staff Institution Screen Tabs Expansion
Extend `frontend_flutter/lib/src/features/staff/presentation/staff_institution_screen.dart` to 5 tabs:
1. **Branding**: Edit University Name, Logo URL, Color Pickers.
2. **Clearance Chain**: Add, reorder, or toggle physical clearance gates.
3. **Refund Slabs**: Set percentage refund windows (UGC/State norms).
4. **Module Switchboard**: Clean toggle switches for all 8 system tabs.
5. **Procedure Editor**: Interactive `ReorderableListView` of steps with in-place Edit and Delete buttons.

---

## 10. Step-by-Step Onboarding Execution Walkthrough

When deploying for a new institution (e.g. *IIT Bombay*):

1. **Step 1: Container Deployment**:
   * Run `docker compose up -d` on the institution's server.
2. **Step 2: Access Administrator Portal**:
   * Open `/staff/institution` with super-admin credentials.
3. **Step 3: Apply Brand Profile**:
   * Set Name: *"Indian Institute of Technology Bombay"*.
   * Set Acronym: *"IITB"*.
   * Pick Colors: Primary Navy `#002D62`, Accent Amber `#FFBF00`.
4. **Step 4: Configure Feature Set**:
   * Turn off unnecessary modules (e.g., if scholarships are handled by an external state portal, toggle `scholarships` $\rightarrow$ `OFF`).
5. **Step 5: Customize Approval Steps**:
   * Open the Withdrawal Procedure Editor.
   * Add *"Department Lab Clearance"* and *"Hostel Mess Caution Settlement"*.
   * Set Accounts refund SLA to *"3 working days"*.
6. **Step 6: Launch Kiosks**:
   * Turn on campus kiosks; all touchscreens immediately reflect IIT Bombay branding, the configured tabs, and the updated clearance steps.

---

## 11. Data Integrity, Concurrency & Backward Compatibility Safeguards

1. **In-Flight Workflow Protection**:
   * Existing student withdrawal requests retain their original clearance gate snapshot in `clearance_gates` with their unique `reference_no`. Changing steps never breaks an ongoing clearance.
2. **Atomic Sequential Step Renumbering**:
   * Step insertions and deletions run inside explicit database transactions (`BEGIN TRANSACTION; ... COMMIT;`), preventing fragmented or duplicate step numbers.
3. **Statutory Audit Trail**:
   * Every change logs to `system_audit_logs` capturing `admin_id`, `action`, `old_value`, and `new_value`.
4. **Safe Default Fallbacks**:
   * If any configuration row is absent, the system falls back to universal higher-education defaults, ensuring zero downtime.

---

## 12. Developer Implementation Checklist

When executing this implementation:
- [ ] Add `GET /api/institution/modules` and `PUT /api/institution/modules` in `backend/routes/institution.py`.
- [ ] Implement `InstitutionService.get_modules()` and `InstitutionService.update_modules()`.
- [ ] Add `GET/POST/PUT/DELETE /api/procedures/{code}/steps` in `backend/routes/procedures.py`.
- [ ] Update `backend/services/withdrawal_workflow.py` to initialize clearance gates from `institution_clearance_chain` table.
- [ ] Create `institution_provider.dart` in Flutter with `enabledModulesProvider`.
- [ ] Add Tabs 4 (Switchboard) and 5 (Procedure Editor) to `staff_institution_screen.dart`.
- [ ] Update `frontend/js/app.js` to dynamically toggle navigation items based on `enabled_modules`.
- [ ] Write integration test suite `backend/tests/test_generalized_onboarding.py` verifying full end-to-end functionality.
