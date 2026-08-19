CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS universities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    code VARCHAR(40) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS students (
    id VARCHAR(40) PRIMARY KEY,
    university_id UUID REFERENCES universities(id),
    name VARCHAR(200) NOT NULL,
    email VARCHAR(254) NOT NULL UNIQUE,
    course VARCHAR(160) NOT NULL,
    branch VARCHAR(80) NOT NULL,
    semester INTEGER NOT NULL,
    enrolled_date DATE NOT NULL,
    attendance NUMERIC(5,2) NOT NULL DEFAULT 75.00,
    cgpa NUMERIC(4,2) NOT NULL DEFAULT 7.00,
    fee_status VARCHAR(20) NOT NULL DEFAULT 'Paid',
    fee_due NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    hostel_status VARCHAR(120) NOT NULL DEFAULT 'Day Scholar',
    scholarship_status VARCHAR(160) NOT NULL DEFAULT 'None',
    academic_performance VARCHAR(80) NOT NULL DEFAULT 'Good',
    interests TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    university_id UUID REFERENCES universities(id),
    username VARCHAR(100) NOT NULL UNIQUE,
    password_hash TEXT,
    name VARCHAR(200) NOT NULL,
    role VARCHAR(80) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS procedure_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    university_id UUID REFERENCES universities(id),
    procedure_code VARCHAR(80) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    UNIQUE(university_id, procedure_code)
);

CREATE TABLE IF NOT EXISTS procedure_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    procedure_id UUID NOT NULL REFERENCES procedure_definitions(id) ON DELETE CASCADE,
    step_number INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    department VARCHAR(120) NOT NULL,
    timeline_text TEXT NOT NULL,
    status_after VARCHAR(80) NOT NULL,
    UNIQUE(procedure_id, step_number)
);

CREATE TABLE IF NOT EXISTS procedure_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    procedure_id UUID NOT NULL REFERENCES procedure_definitions(id) ON DELETE CASCADE,
    document_key VARCHAR(100) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    mandatory BOOLEAN NOT NULL DEFAULT true,
    applicable_reason VARCHAR(80) NOT NULL DEFAULT 'all',
    form_url TEXT,
    UNIQUE(procedure_id, document_key)
);

CREATE TABLE IF NOT EXISTS procedure_forms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    procedure_id UUID NOT NULL REFERENCES procedure_definitions(id) ON DELETE CASCADE,
    form_key VARCHAR(100) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    storage_url TEXT NOT NULL,
    issuing_department VARCHAR(120) NOT NULL,
    UNIQUE(procedure_id, form_key)
);

CREATE TABLE IF NOT EXISTS withdrawal_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    university_id UUID REFERENCES universities(id),
    student_id VARCHAR(40) NOT NULL REFERENCES students(id),
    reference_no VARCHAR(40) NOT NULL UNIQUE,
    reason TEXT NOT NULL,
    detected_intent VARCHAR(80),
    status VARCHAR(80) NOT NULL DEFAULT 'pending',
    current_step INTEGER NOT NULL DEFAULT 1,
    refund_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS withdrawal_checklist_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES withdrawal_requests(id) ON DELETE CASCADE,
    document_key VARCHAR(100) NOT NULL,
    label VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(40) NOT NULL DEFAULT 'pending',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    university_id UUID REFERENCES universities(id),
    student_id VARCHAR(40) NOT NULL REFERENCES students(id),
    request_id UUID REFERENCES withdrawal_requests(id),
    file_name VARCHAR(255) NOT NULL,
    storage_key TEXT NOT NULL,
    classification VARCHAR(80) NOT NULL DEFAULT 'other',
    ocr_data JSONB,
    verification_status VARCHAR(40) NOT NULL DEFAULT 'pending',
    verification_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS workflow_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES withdrawal_requests(id) ON DELETE CASCADE,
    status VARCHAR(80) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    actor VARCHAR(80) NOT NULL DEFAULT 'system',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    university_id UUID REFERENCES universities(id),
    actor_id UUID REFERENCES users(id),
    actor_role VARCHAR(80),
    action VARCHAR(120) NOT NULL,
    entity_type VARCHAR(120) NOT NULL,
    entity_id VARCHAR(120),
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
