"""Phase 12: Multi-campus configuration."""


def _staff_headers(client):
    login = client.post("/api/auth/staff/login", json={"username": "registrar_staff"})
    return {"Authorization": f"Bearer {login.json()['token']}"}


def test_campuses_and_student_lookup_are_staff_only(client):
    assert client.get("/api/campuses").status_code == 401
    headers = _staff_headers(client)
    campuses = client.get("/api/campuses", headers=headers)
    assert campuses.status_code == 200
    assert {campus["code"] for campus in campuses.json()} >= {"NOIDA", "MUMBAI", "LUCKNOW"}

    students = client.get("/api/campuses/students?campus_code=MUMBAI", headers=headers)
    assert students.status_code == 200
    assert students.json()
    assert all(student["campus_code"] == "MUMBAI" for student in students.json())


def test_campus_rules_drive_new_workflow_assignment(client):
    headers = _staff_headers(client)
    update = client.put(
        "/api/campuses/MUMBAI/procedure-rules/withdrawal",
        headers=headers,
        json={"default_department": "Registry", "target_days": 7, "policy_note": "Fast-track pilot."},
    )
    assert update.status_code == 200
    assert update.json()["default_department"] == "Registry"

    workflow = client.post("/api/workflows", json={"procedure_type": "withdrawal", "student_id": "STU003"})
    assert workflow.status_code == 200
    assert workflow.json()["campus_code"] == "MUMBAI"
    assert workflow.json()["assigned_department"] == "Registry"
