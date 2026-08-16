from io import BytesIO


class TestPhase8DocumentIntelligence:
    def test_invalid_document_type_is_rejected(self, client):
        response = client.post(
            "/api/documents/upload",
            data={"student_id": "STU001"},
            files={"file": ("notes.txt", b"hello world", "text/plain")},
        )
        assert response.status_code == 400
        assert "Only PDF, JPG, and PNG" in response.json()["detail"]

    def test_document_metadata_and_duplicate_detection(self, client):
        first = client.post(
            "/api/documents/upload",
            data={"student_id": "STU001"},
            files={"file": ("id_card.png", b"fake-id-image-1", "image/png")},
        )
        assert first.status_code == 200
        body = first.json()
        assert body["ocr_data"]["document_type"] in {"ID Card", "id_card"}
        assert "metadata" in body["ocr_data"]
        assert body["ocr_data"]["metadata"]["file_size_bytes"] == len(b"fake-id-image-1")

        second = client.post(
            "/api/documents/upload",
            data={"student_id": "STU001"},
            files={"file": ("id_card_2.png", b"fake-id-image-1", "image/png")},
        )
        assert second.status_code == 200
        flags = second.json()["fraud_flags"]
        assert any("duplicate" in flag.lower() for flag in flags)
