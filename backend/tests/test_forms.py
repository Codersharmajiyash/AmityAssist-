"""
Tests for forms catalog and static forms file serving.
"""

from fastapi.testclient import TestClient
from backend.main import app

client = TestClient(app)


def test_get_forms_catalog_returns_all_documents():
    response = client.get("/api/forms/catalog")
    assert response.status_code == 200
    data = response.json()
    assert "count" in data
    assert data["count"] >= 31
    assert "forms" in data
    assert len(data["forms"]) >= 31

    # Verify key properties of returned forms
    first_form = data["forms"][0]
    assert "name" in first_form
    assert "category" in first_form
    assert "department" in first_form
    assert "download_url" in first_form
    assert "file_type" in first_form


def test_get_forms_catalog_search_and_filter():
    response = client.get("/api/forms/catalog?category=Finance")
    assert response.status_code == 200
    data = response.json()
    assert data["count"] > 0
    for form in data["forms"]:
        assert form["category"].lower() == "finance"

    search_resp = client.get("/api/forms/catalog?q=transport")
    assert search_resp.status_code == 200
    s_data = search_resp.json()
    assert s_data["count"] >= 1
    assert "transport" in s_data["forms"][0]["name"].lower() or "transport" in s_data["forms"][0]["description"].lower() or "transport" in s_data["forms"][0]["department"].lower()


def test_get_form_categories():
    response = client.get("/api/forms/categories")
    assert response.status_code == 200
    data = response.json()
    assert "categories" in data
    assert len(data["categories"]) > 0


def test_static_forms_file_download():
    # Test downloading one of the static documents
    response = client.get("/forms/1.%20DL%20FORM.docx")
    assert response.status_code == 200
    assert len(response.content) > 0
