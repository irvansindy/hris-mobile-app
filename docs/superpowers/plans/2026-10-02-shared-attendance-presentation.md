# Shared Attendance Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Absensi use one presentation tree in demo and production while retaining server submission in production and local Face ID verification plus persistence in demo.

**Architecture:** Reuse the existing `AttendanceRepository`, `AttendanceContext`, `AttendanceEntity`, and history provider as the data boundary. Extract the existing attendance overview into a shared widget, replace mode checks with an optional Face ID capability, and remove demo summary widget injection. Demo continues to override repositories and the capability; production receives no fabricated data.

**Tech Stack:** Flutter, Dart, Riverpod, `flutter_test`

**Spec:** `docs/superpowers/specs/2026-09-30-shared-presentation-demo-production-design.md`

## Global Constraints

- Demo and production must render the same Absensi widget tree and section order.
- `DEMO_MODE` may configure repositories, offline adapters, authentication, and the banner, but not Absensi layout.
- Production must never fall back to local demo history, location, Face ID, or success messages.
- Demo attendance must still require successful local Face ID verification before persistence.
- Loading, error, permission, empty, and incomplete-history states remain explicit.
- Preserve the existing uncommitted Absensi redesign as the baseline; stage no unrelated worktree changes.
- Keep controls reachable at 320 dp and 200% text, with at least 44 dp touch targets and bottom safe-area clearance.
- Add no package or speculative abstraction.
- Prefix repository shell commands with `rtk`.

## Review Focus

- A completed attendance record disables another submission in both modes instead of allowing an unintended second clock-in.
- A missing local Face ID capability follows the server confirmation path and never reads demo storage.
- Incomplete or paginated history renders an honest unavailable summary rather than totals from a partial page.
- Long branch names, warnings, and status labels reflow without horizontal overflow at 320 dp and 200% text.
- Closing or failing local Face ID never calls `clockIn` or `clockOut`, and modal routes obscure floating navigation actions.

---

### Task 1: Extract the shared attendance overview

**Files:**
- Create: `lib/features/attendance/presentation/widgets/attendance_overview.dart`
- Modify: `lib/features/attendance/presentation/screens/attendance_screen.dart`
- Create: `test/features/attendance/attendance_overview_test.dart`

**Interfaces:**
- Consumes: `AttendanceOverview({required AttendanceContext contextValue, required AttendanceEntity record, required AsyncValue<AttendanceHistoryPage> history})` inputs already available in `AttendanceScreen`.
- Produces: one data-source-neutral overview with keys `attendance-summary-section`, `attendance-location-section`, `attendance-metrics-section`, and `attendance-state-section`.

- [ ] **Step 1: Write failing shared-widget tests**

Add tests proving available history renders real counts, average check-in, location state, and record state; incomplete history renders the explicit unavailable summary without partial totals; and a long location/warning fixture at 320 dp with 200% text produces no overflow while every section remains reachable.

- [ ] **Step 2: Run the focused test and verify failure**

Run: `rtk flutter test test/features/attendance/attendance_overview_test.dart --reporter compact`

Expected: FAIL because `AttendanceOverview` and its structural keys do not exist.

- [ ] **Step 3: Implement the shared widget**

Move `_ProductionAttendanceSummary`, `_PolicyCard`, and `_AttendanceMetric` from `attendance_screen.dart` into `attendance_overview.dart`. Rename the root widget to `AttendanceOverview`, expose only the constructor above, add the four stable keys, and retain the current truthful summary calculations and responsive stacking behavior. Render it for every non-null `AttendanceToday`, regardless of data source.

- [ ] **Step 4: Run the focused test and verify pass**

Run: `rtk flutter test test/features/attendance/attendance_overview_test.dart --reporter compact`

Expected: PASS.

- [ ] **Step 5: Commit the overview**

```bash
rtk git add lib/features/attendance/presentation/widgets/attendance_overview.dart lib/features/attendance/presentation/screens/attendance_screen.dart test/features/attendance/attendance_overview_test.dart
rtk git commit -m "refactor(attendance): share attendance overview"
```

### Task 2: Replace demo-mode action branching with a Face ID capability

**Files:**
- Modify: `lib/core/face_id/face_id_providers.dart`
- Modify: `lib/core/config/demo_mode.dart`
- Modify: `lib/demo/demo_overrides.dart`
- Delete: `lib/demo/demo_attendance_summary.dart`
- Modify: `lib/features/attendance/presentation/screens/attendance_screen.dart`
- Modify: `test/features/attendance/attendance_screen_test.dart`
- Modify: `test/demo/demo_app_test.dart`

**Interfaces:**
- Consumes: the existing local Face ID launcher implementation and `AttendanceRepository` overrides.
- Produces: `AttendanceFaceVerificationLauncher` and `attendanceFaceVerificationLauncherProvider`, a nullable `Provider<AttendanceFaceVerificationLauncher?>` whose null value means server confirmation and whose non-null value means local Face ID verification is required before repository submission.

- [ ] **Step 1: Write failing behavior tests**

Update attendance tests to override `attendanceFaceVerificationLauncherProvider` instead of `demoModeProvider`. Assert successful verification submits once, camera cancellation and enrollment failure submit zero times, server mode opens the confirmation sheet, and a record with `checkedOutAt` disables submission in either mode. Extend the demo app test to assert the shared overview structural keys.

- [ ] **Step 2: Run the focused tests and verify failure**

Run: `rtk flutter test test/features/attendance/attendance_screen_test.dart test/demo/demo_app_test.dart --reporter compact`

Expected: FAIL because the capability provider and shared demo overview wiring do not exist.

- [ ] **Step 3: Wire capability-based behavior**

Rename the launcher typedef to `AttendanceFaceVerificationLauncher` and add `attendanceFaceVerificationLauncherProvider` with a null default. Override it in `demoOverrides` with the provided launcher or the existing local Face ID launcher. In `AttendanceScreen`, remove reads of `demoModeProvider` and `demoAttendanceSummaryBuilderProvider`; select the verification flow from the nullable capability, disable submission after checkout in all modes, and select success copy from the actual path used. Add stable keys `attendance-header`, `attendance-submit-action`, `attendance-history-picker`, `attendance-history-filters`, and `attendance-history-content`. Remove the obsolete summary provider, override, import, and file. Do not change repository contracts or Face ID matching.

- [ ] **Step 4: Run the focused tests and verify pass**

Run: `rtk flutter test test/features/attendance/attendance_screen_test.dart test/demo/demo_app_test.dart --reporter compact`

Expected: PASS.

- [ ] **Step 5: Commit capability integration**

```bash
rtk git add lib/core/face_id/face_id_providers.dart lib/core/config/demo_mode.dart lib/demo/demo_overrides.dart lib/demo/demo_attendance_summary.dart lib/features/attendance/presentation/screens/attendance_screen.dart test/features/attendance/attendance_screen_test.dart test/demo/demo_app_test.dart
rtk git commit -m "refactor(attendance): switch modes through capabilities"
```

### Task 3: Lock Absensi parity and repository safety

**Files:**
- Create: `test/features/attendance/attendance_presentation_parity_test.dart`
- Modify: `test/architecture/dependency_rules_test.dart`
- Modify: `test/features/safety/no_demo_ui_test.dart`
- Modify if visually approved: `test/goldens/stage4/attendance_fixture_light.png`
- Modify if visually approved: `test/goldens/stage4/attendance_fixture_dark.png`

**Interfaces:**
- Consumes: the shared `AttendanceScreen`, repository overrides, and optional Face ID capability from Tasks 1 and 2.
- Produces: automated evidence that demo and production share Absensi structure without demo data leaking into production.

- [ ] **Step 1: Write parity and architecture regression tests**

Pump `AttendanceScreen` once with a local demo repository fixture and once with a production repository fixture. Assert the same ordered keys for header, summary, location, metrics, state, submit action, history picker, filters, and history content. Extend architecture checks to reject `demoAttendanceSummaryBuilderProvider` and any `demoModeProvider` read from attendance presentation.

- [ ] **Step 2: Run focused parity tests**

Run: `rtk flutter test test/features/attendance/attendance_presentation_parity_test.dart test/architecture/dependency_rules_test.dart test/features/safety/no_demo_ui_test.dart --reporter compact`

Expected: PASS after Tasks 1 and 2, with production containing no demo labels or records.

- [ ] **Step 3: Run visual and accessibility regression**

Run: `rtk flutter test test/stage4_golden_test.dart test/features/attendance --reporter compact`

Expected: PASS without baseline updates, or produce failure images for comparison. Update golden files only after the render matches the approved HTML reference.

- [ ] **Step 4: Run repository quality gates**

Run:

```bash
rtk dart format --output=none --set-exit-if-changed lib test tool integration_test
rtk flutter analyze
rtk flutter test --coverage --reporter compact
```

Expected: formatting unchanged, analyzer reports no issues, and the full suite passes.

- [ ] **Step 5: Perform manual mode checks when Android is available**

Run production configuration and `--dart-define=DEMO_MODE=true` separately. Verify identical section order, safe areas, scrolling, disabled completed state, modal obstruction, production confirmation, and demo Face ID success/cancel/failure. Record the check as deferred when no Android device is connected; never substitute Linux or Chrome for camera acceptance.

- [ ] **Step 6: Commit parity artifacts**

```bash
rtk git add test/features/attendance/attendance_presentation_parity_test.dart test/architecture/dependency_rules_test.dart test/features/safety/no_demo_ui_test.dart test/stage4_golden_test.dart test/goldens/stage4/attendance_fixture_light.png test/goldens/stage4/attendance_fixture_dark.png
rtk git commit -m "test(attendance): verify shared presentation parity"
```

Skip unchanged or unapproved golden artifacts when staging.
