"""Phase 11: Advanced analytics and reporting."""


def _staff_headers(client):
    response = client.post("/api/auth/staff/login", json={"username": "registrar_staff"})
    return {"Authorization": f"Bearer {response.json()['token']}"}


def test_reports_require_staff_authentication(client):
    assert client.get("/api/reports/analytics").status_code == 401


def test_analytics_and_funnel_reports(client):
    headers = _staff_headers(client)
    analytics = client.get("/api/reports/analytics", headers=headers)
    assert analytics.status_code == 200
    assert {"students", "workflows", "open_grievances"} <= analytics.json().keys()

    funnel = client.get("/api/reports/funnel", headers=headers)
    assert funnel.status_code == 200
    assert "stages" in funnel.json()


def test_bottlenecks_and_exports(client):
    headers = _staff_headers(client)
    bottlenecks = client.get("/api/reports/bottlenecks", headers=headers)
    assert bottlenecks.status_code == 200
    assert "bottlenecks" in bottlenecks.json()

    csv_response = client.get("/api/reports/export?report=analytics&format=csv", headers=headers)
    assert csv_response.status_code == 200
    assert csv_response.headers["content-type"].startswith("text/csv")
    assert b"metric,value" in csv_response.content

    pdf_response = client.get("/api/reports/export?report=funnel&format=pdf", headers=headers)
    assert pdf_response.status_code == 200
    assert pdf_response.headers["content-type"].startswith("application/pdf")
    assert pdf_response.content.startswith(b"%PDF-")
