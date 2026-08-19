from io import BytesIO

from backend.config import settings
from backend.database.connection import get_database_backend
from backend.services.cache_service import cache_service
from backend.services.storage_service import storage_service


class TestPhase7ProductionRuntimeConfig:
    def test_database_defaults_to_sqlite_in_local_dev(self):
        assert settings.database_url.startswith("sqlite")
        assert get_database_backend() == "sqlite"

    def test_cache_and_storage_fallback_without_external_services(self):
        assert cache_service.get_json("missing-key") is None
        cache_service.set_json("team:key", {"phase": 7}, ttl_seconds=60)
        assert cache_service.get_json("team:key") == {"phase": 7}

        key = "phase7-demo.txt"
        saved = storage_service.upload_document(key, BytesIO(b"demo-doc"), content_type="text/plain")
        assert saved == key
        assert storage_service.read_document(key) == b"demo-doc"
