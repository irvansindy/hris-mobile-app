# HRMS Mobile App

Employee self-service application built with Flutter, feature-first pragmatic
Clean Architecture, Riverpod, and Dio. The original `IndexedStack` navigation
and visual presentation are intentionally preserved.

See [Architecture](docs/ARCHITECTURE.md) for dependency rules, data flow,
security guidance, testing requirements, and instructions for adding features.

## Getting started

```bash
cp .env.example .env
flutter pub get
flutter run --dart-define-from-file=.env
```

`.env` is read by the Flutter tool as compile-time public configuration and is
not bundled as an application asset. Do not put tokens, passwords, API secrets,
private keys, or service credentials in it.

For Flutter Web development through the local CORS proxy:

```bash
dart run tool/dev_cors_proxy.dart
```

Keep the proxy running, then use a second terminal:

```bash
flutter run -d chrome \
  --dart-define=APP_ENV=development \
  --dart-define=BASE_URL=http://localhost:8085/api/v1 \
  --dart-define=CONNECT_TIMEOUT_MS=15000 \
  --dart-define=RECEIVE_TIMEOUT_MS=15000 \
  --dart-define=ENABLE_LOGGING=false
```

The proxy is localhost-only and intended only for development. Production must
configure CORS on the API/reverse proxy for the deployed frontend origin.

A release/profile build requires an explicit HTTPS endpoint and refuses network
logging:

```bash
flutter build appbundle --release \
  --dart-define=APP_ENV=production \
  --dart-define=BASE_URL=https://api.example.com/api/v1 \
  --dart-define=ENABLE_LOGGING=false
```

Quality checks:

```bash
flutter analyze
flutter test
```

Native JUnit regression (run from `android/` with the Android SDK configured):

```bash
rtk proxy ./gradlew :app:verifyDependencySafety -I ../tool/verify_android_dependencies.gradle
```

This resolves debug/profile/release graphs, rejects unpatched JUnit, and checks
that JUnit is absent from release. It is not a full vulnerability scan. See the
[native dependency audit](<docs/Report QA-03 Audit Dependency Native - 2026-10-20.md>)
for OSV results and remaining iOS/binary checks.

After an Android App Bundle build, verify pinned PDFium bytes before uploading:

```bash
rtk dart --packages=.dart_tool/package_config.json tool/verify_native_pdfium.dart
```

Requires `unzip` and `shasum` on PATH (`zip` is also needed by the verifier tests).
The command checks the three Android hook-cache libraries and the AAB, rejects
missing/duplicate/unknown binaries or package-version changes, and returns a
nonzero exit code on failure. Android CI runs it after build and before upload.
An optional positional argument selects another AAB; there is no baseline-update
or skip flag. Update the pinned hashes only through a reviewed provenance audit.
Direct script execution avoids running package build hooks inside the verifier.
This is a post-build integrity gate, not pre-extraction download verification,
an iOS gate, or native vulnerability clearance. See the
[provenance audit](<docs/Report QA-03 Provenance Binary Native - 2026-10-21.md>).

Authentication and attendance use the configured HRMS API. Other modules keep
replaceable local adapters until their response schemas are finalized.

Authentication is connected to the HRMS reference API configured by
`BASE_URL`. The repository's HTTP endpoint is a development-only fallback and
cannot start a release/profile build.

## Local push simulator

```bash
rtk flutter run --dart-define=DEMO_MODE=true
rtk flutter run --dart-define-from-file=.env --dart-define=PUSH_MODE=dummy
```

The second command uses server repositories with local push simulation and
requires a valid login. Dummy registration stays local; it does not send sample
tokens to the API or test Firebase/APNs delivery. `PUSH_MODE` defaults to
`disabled`; dummy is debug-only and rejected in profile/release builds.

See [local verification report](docs/Tahap%206%20Push%20Notification%20dan%20Deep%20Link.md)
and [pending live acceptance](docs/Tahap%206%20Acceptance%20Push%20Live%20Tertunda.md).
Production Firebase/APNs configuration remains pending; local success is not release approval.

## Android development Firebase

Place the development Android client configuration at
`android/app/src/debug/google-services.json` (gitignored). It must match the
temporary package `com.example.hrm_app`. Do not put service-account credentials
or Firebase server keys in the app or `.env`.

```bash
rtk flutter run --dart-define-from-file=.env --dart-define=APP_ENV=development --dart-define=DEMO_MODE=false --dart-define=PUSH_MODE=firebase --dart-define=ENABLE_LOGGING=false
```

This mode uses real FCM only on Android development debug. Registration remains
Console-only: the token is never sent to the HRIS backend, including its HTTP
endpoint. After employee login, open Notifications and use the debug panel to
activate permission and explicitly copy the token for a Firebase Console test.
Foreground messages refresh the inbox; there is no foreground OS banner.
Demo continues to use dummy push. Profile/release Firebase builds are rejected.

See [development setup and test report](docs/Firebase%20Android%20Development.md).

## Flutter resources

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
