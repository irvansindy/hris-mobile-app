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
Real Firebase configuration remains pending; local success is not release approval.

## Flutter resources

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
