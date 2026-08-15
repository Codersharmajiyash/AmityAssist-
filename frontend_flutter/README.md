# UNIASSIST Flutter Frontend

This is the Phase 3 Flutter/Riverpod scaffold for UNIASSIST.

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
