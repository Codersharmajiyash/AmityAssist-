"""Phase 14: production hardening."""


def _staff_headers(client):
    token = client.post("/api/auth/staff/login", json={"username": "registrar_staff"}).json()["token"]
    return {"Authorization": f"Bearer {token}"}


def test_health_headers_and_readiness(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-frame-options"] == "DENY"
    assert response.headers["x-request-id"]
    assert "app;dur=" in response.headers["server-timing"]

    readiness = client.get("/api/health/ready")
    assert readiness.status_code == 200
    assert readiness.json()["status"] in {"ready", "degraded"}


def test_telemetry_is_staff_protected(client):
    assert client.get("/api/health/telemetry").status_code == 401
    response = client.get("/api/health/telemetry", headers=_staff_headers(client))
    assert response.status_code == 200
    assert "requests" in response.json()
