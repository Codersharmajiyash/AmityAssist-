# UNIASSIST Flutter Frontend

This is the Phase 3 Flutter/Riverpod scaffold for UNIASSIST.

This is the correct place to build the real kiosk/tablet frontend. The root `frontend/` folder is only a static HTML prototype used to validate API behavior quickly in a browser.

Kiosk requirements for this app:

- Touch-first screens with large controls.
- Minimal typing, using guided choices where possible.
- Clear student session reset after completion or inactivity.
- Privacy-aware display of profile, document, fee, grievance, and withdrawal data.
- Official forms ready for download, print, or staff handoff.
- Voice support when the host device/browser supports it.

The Flutter CLI is not installed in the current machine, so this folder contains the source structure and app code but not generated platform folders such as `android/`, `ios/`, `windows/`, or `web/`.

When Flutter is installed, run:

```powershell
cd frontend_flutter
flutter create .
flutter pub get
flutter run -d chrome
```

The app is structured for Clean Architecture:

```text
lib/
  main.dart
  src/
    app/
    core/
    features/
      auth/
      withdrawal/
```
