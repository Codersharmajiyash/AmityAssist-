-- Phase 13: production extensions for workflow, notifications, analytics, and campuses.
CREATE TABLE IF NOT EXISTS campuses (
    code VARCHAR(32) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    city VARCHAR(120) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

ALTER TABLE students ADD COLUMN IF NOT EXISTS campus_code VARCHAR(32) NOT NULL DEFAULT 'NOIDA';

CREATE TABLE IF NOT EXISTS campus_procedure_rules (
    campus_code VARCHAR(32) NOT NULL REFERENCES campuses(code),
    procedure_type VARCHAR(80) NOT NULL,
    default_department VARCHAR(120) NOT NULL,
    target_days INTEGER NOT NULL CHECK(target_days > 0),
    policy_note TEXT,
    PRIMARY KEY(campus_code, procedure_type)
);

CREATE TABLE IF NOT EXISTS workflows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id VARCHAR(40) NOT NULL REFERENCES students(id),
    procedure_type VARCHAR(80) NOT NULL,
    status VARCHAR(80) NOT NULL DEFAULT 'initiated',
    assigned_department VARCHAR(120),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    campus_code VARCHAR(32) NOT NULL DEFAULT 'NOIDA' REFERENCES campuses(code),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS workflows_campus_status_idx ON workflows(campus_code, status);

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id VARCHAR(40) NOT NULL REFERENCES students(id),
    notification_type VARCHAR(80) NOT NULL,
    title VARCHAR(250) NOT NULL,
    message TEXT NOT NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'normal',
    read_status VARCHAR(20) NOT NULL DEFAULT 'unread',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS notifications_student_read_idx ON notifications(student_id, read_status);

INSERT INTO campuses (code, name, city) VALUES
  ('NOIDA', 'Amity University Noida', 'Noida'),
  ('MUMBAI', 'Amity University Mumbai', 'Mumbai'),
  ('LUCKNOW', 'Amity University Lucknow', 'Lucknow')
ON CONFLICT (code) DO NOTHING;
