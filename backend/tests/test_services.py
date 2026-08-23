"""
Tests for public Guest Services endpoints (overview, faqs, directory, notices).
"""

from fastapi.testclient import TestClient
from backend.main import app

client = TestClient(app)


def test_public_services_overview():
    response = client.get("/api/services/overview")
    assert response.status_code == 200
    data = response.json()
    assert "services" in data
    assert len(data["services"]) >= 8
    
    ids = [s["id"] for s in data["services"]]
    assert "withdrawal" in ids
    assert "scholarships" in ids
    assert "certificates" in ids
    assert "faqs" in ids
    assert "documents" in ids


def test_public_services_faqs():
    response = client.get("/api/services/faqs")
    assert response.status_code == 200
    data = response.json()
    assert "faqs" in data
    assert len(data["faqs"]) >= 5
    
    first = data["faqs"][0]
    assert "question" in first
    assert "answer" in first
    assert "category" in first


def test_public_services_directory():
    response = client.get("/api/services/directory")
    assert response.status_code == 200
    data = response.json()
    assert "contacts" in data
    assert len(data["contacts"]) >= 4
    
    dept_names = [c["department"] for c in data["contacts"]]
    assert any("Registrar" in d for d in dept_names)


def test_public_services_notices():
    response = client.get("/api/services/notices")
    assert response.status_code == 200
    data = response.json()
    assert "notices" in data


def test_guest_chat_without_login():
    response = client.post("/api/chat/message", json={
        "message": "I want withdrawal process details"
    })
    assert response.status_code == 200
    data = response.json()
    assert "reply" in data
    assert len(data["reply"]) > 0
