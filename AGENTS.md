# Repository Guidelines

## Project Structure & Module Organization

Application code lives in `lib/`. Features use a feature-first layout under `lib/features/<feature>/`, commonly split into `data`, `domain`, and `presentation`. Shared configuration, networking, security, theme, and widgets belong in `lib/core/`; routing and the application shell live in `lib/app/`. Demo-only repositories and local fixtures are isolated in `lib/demo/` and must not leak into production builds.

Tests mirror the source structure in `test/`. API contract, repository, widget, architecture, safety, and golden tests are kept in dedicated subdirectories. Device-level flows live in `integration_test/`. Static images and fonts are in `assets/`, developer utilities in `tool/`, and technical decisions and implementation reports in `docs/`.

## Build, Test, and Development Commands

Prefix repository shell commands with `rtk`.

```bash
rtk flutter pub get
rtk flutter run --dart-define-from-file=.env
rtk flutter analyze
rtk dart format --output=none --set-exit-if-changed lib test tool integration_test
rtk flutter test --coverage
```

Use `rtk flutter run --dart-define=DEMO_MODE=true` only for local debug demonstrations. Release builds require explicit production configuration and an HTTPS `BASE_URL`; see `README.md` and `.github/workflows/mobile-ci.yml`.

## Coding Style & Naming Conventions

Use Dart's standard two-space indentation and run `dart format`. Follow `flutter_lints` from `analysis_options.yaml`. Name files in `snake_case`, types in `UpperCamelCase`, and variables, methods, and Riverpod providers in `lowerCamelCase`. Keep UI independent of its data source: demo and production should share screens and controllers while repositories provide different data. Do not add secrets, tokens, credentials, or environment-specific URLs to source files.

## Testing Guidelines

Use `flutter_test` for unit and widget tests and `integration_test` for device flows. Test files must end in `_test.dart`; place feature tests under `test/features/<feature>/`. Add contract tests for API schema changes, repository tests for mapping and failures, and golden tests for intentional visual changes. Run the full suite before opening a pull request and review any updated golden images.

## Commit & Pull Request Guidelines

History generally follows Conventional Commit-style subjects such as `feat(authentication): ...`, `feat: ...`, and `refactor: ...`. Keep commits focused and use an imperative summary. Pull requests should explain scope, testing performed, configuration changes, and known limitations. Link the relevant issue or task and include before/after screenshots for UI changes. CI format, analyzer, tests, release-safety guards, and platform build checks must pass.
