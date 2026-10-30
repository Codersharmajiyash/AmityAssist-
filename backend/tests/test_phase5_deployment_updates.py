import json
import os
from pathlib import Path
from backend.routes.system import get_system_version

def test_system_version_endpoint():
    data = get_system_version()
    assert data["server_version"] == "2.4.0"
    assert data["min_client_version"] == "2.0.0"
    assert "desktop_exe_url" in data
    assert "android_apk_url" in data
    assert "changelog" in data

def test_pwa_manifest_json():
    root = Path(__file__).resolve().parent.parent.parent
    manifest_path = root / "frontend_flutter" / "web" / "manifest.json"
    assert manifest_path.exists()

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    assert manifest["name"] == "UniAssist — University Student Services Hub"
    assert manifest["short_name"] == "UniAssist"
    assert manifest["display"] == "standalone"
    assert manifest["background_color"] == "#0A192F"
    assert manifest["theme_color"] == "#0A192F"
    assert len(manifest["icons"]) >= 2
    assert any(icon["sizes"] == "192x192" for icon in manifest["icons"])
    assert any(icon["sizes"] == "512x512" for icon in manifest["icons"])

def test_pwa_service_worker_autoupdater_script():
    root = Path(__file__).resolve().parent.parent.parent
    index_path = root / "frontend_flutter" / "web" / "index.html"
    assert index_path.exists()

    with open(index_path, "r", encoding="utf-8") as f:
        html = f.read()

    assert "flutter_service_worker.js?v=" in html
    assert "skipWaiting" in html
    assert "controllerchange" in html
    assert "window.location.reload()" in html

def test_desktop_launcher_batch_script():
    root = Path(__file__).resolve().parent.parent.parent
    launcher_path = root / "launcher" / "run_uniassist.bat"
    assert launcher_path.exists()

    with open(launcher_path, "r", encoding="utf-8") as f:
        content = f.read()

    assert "UniAssist Desktop Client" in content
    assert "UniAssist.exe" in content
    assert "UniAssist_update.exe" in content
    assert "api/system/version" in content

def test_kiosk_3am_watchdog_powershell_script():
    root = Path(__file__).resolve().parent.parent.parent
    watchdog_path = root / "launcher" / "kiosk_watchdog.ps1"
    assert watchdog_path.exists()

    with open(watchdog_path, "r", encoding="utf-8") as f:
        content = f.read()

    assert "03:00 AM" in content
    assert "Stop-Process" in content
    assert "UniAssist.exe" in content
    assert "--kiosk" in content
    assert "--fullscreen" in content

def test_kiosk_inactivity_wrapper_widget():
    root = Path(__file__).resolve().parent.parent.parent
    wrapper_path = root / "frontend_flutter" / "lib" / "src" / "features" / "kiosk" / "presentation" / "kiosk_inactivity_wrapper.dart"
    assert wrapper_path.exists()

    with open(wrapper_path, "r", encoding="utf-8") as f:
        content = f.read()

    assert "class KioskInactivityWrapper" in content
    assert "_idleTimeoutSeconds = 45" in content
    assert "_warningCountdownSeconds = 10" in content
    assert "_purgeSessionAndLogout" in content
    assert "Are you still there?" in content
