# Shared Home Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Beranda use one presentation tree in demo and production while allowing repositories to provide different, truthful data.

**Architecture:** Extend `DashboardSnapshot` with data-source-neutral team, shift, and attendance-pattern values. Render those values through shared dashboard widgets and keep mode switching exclusively in repository provider overrides. Production uses explicit unavailable state when its API does not supply a section; demo supplies local fixture values.

**Tech Stack:** Flutter, Dart, Riverpod, `flutter_test`, golden tests

**Spec:** `docs/superpowers/specs/2026-09-30-shared-presentation-demo-production-design.md`

## Global Constraints

- Demo and production must use the same authenticated Beranda widget tree.
- `DEMO_MODE` may change repositories, local persistence, capabilities, and the banner, but not layout.
- Production must never fall back to demo values after missing data or API failure.
- Existing HTML-approved spacing, component order, safe areas, and modal behavior remain the visual reference.
- Preserve all unrelated working-tree changes and do not regenerate goldens without visual review.
- Prefix repository shell commands with `rtk`.

## Review Focus

- Missing production endpoints render an unavailable state inside the same section card, without demo content.
- Empty-but-available team or attendance data renders an explicit empty state rather than disappearing.
- Long employee, division, location, and shift labels truncate or wrap without horizontal overflow.
- Text scaling to 200% preserves section order and leaves all actions reachable.
- Demo repository updates still refresh the same shared Beranda sections without network access.

---

### Task 1: Dashboard data contract for shared sections

**Files:**
- Modify: `lib/features/dashboard/domain/entities/dashboard_snapshot.dart`
- Modify: `lib/demo/demo_repositories.dart`
- Test: `test/features/dashboard/dashboard_repository_test.dart`

**Interfaces:**
- Consumes: Existing `DashboardRepository.current` and `DashboardSnapshot`.
- Produces: `DashboardTeamSummary`, `DashboardTeamMember`, `DashboardShiftSummary`, `DashboardAttendancePattern`, and `DashboardAttendancePatternRow` fields on `DashboardSnapshot`.

- [ ] **Step 1: Write failing repository tests**

Add tests proving `DemoDashboard.current` exposes an available team summary, next shift, and attendance pattern, while a default `DashboardSnapshot` leaves all three unavailable. Assert attendance pattern row levels and percentages are domain values, not colors or widgets.

- [ ] **Step 2: Run the focused test and verify failure**

Run: `rtk flutter test test/features/dashboard/dashboard_repository_test.dart --reporter compact`

Expected: FAIL because the shared section models and snapshot fields do not exist.

- [ ] **Step 3: Add the domain interfaces**

Add these immutable types to `dashboard_snapshot.dart`:

- `DashboardTeamMember({required String initials, required String label, required String detail})`
- `DashboardTeamSummary({bool available = false, int presentCount = 0, int leaveCount = 0, String? division, List<DashboardTeamMember> members = const []})`
- `DashboardShiftSummary({bool available = false, String? dayLabel, String? timeRange, String? location, String? typeLabel})`
- `DashboardAttendancePatternRow({required String label, required List<int> levels})`, where levels are `0..3` intensity values.
- `DashboardAttendancePattern({bool available = false, int periodDays = 90, List<DashboardAttendancePatternRow> rows = const [], int onsitePercent = 0, int remotePercent = 0, int leavePercent = 0})`

Add `teamSummary`, `nextShift`, and `attendancePattern` to `DashboardSnapshot`, each defaulting to its unavailable const value. Populate them in `DemoDashboard.current` with the existing demo section content. Do not populate them in production repository mapping until a backend contract exists.

- [ ] **Step 4: Run the focused test and verify pass**

Run: `rtk flutter test test/features/dashboard/dashboard_repository_test.dart --reporter compact`

Expected: PASS.

- [ ] **Step 5: Commit the data contract**

```bash
rtk git add lib/features/dashboard/domain/entities/dashboard_snapshot.dart lib/demo/demo_repositories.dart test/features/dashboard/dashboard_repository_test.dart
rtk git commit -m "refactor(dashboard): add shared home section data"
```

### Task 2: Shared team, shift, and attendance-pattern widgets

**Files:**
- Create: `lib/features/dashboard/presentation/widgets/home_support_sections.dart`
- Create: `test/features/dashboard/home_support_sections_test.dart`

**Interfaces:**
- Consumes: `DashboardTeamSummary`, `DashboardShiftSummary`, and `DashboardAttendancePattern` from Task 1.
- Produces: `HomeSupportSections({required DashboardTeamSummary team, required DashboardShiftSummary shift, required DashboardAttendancePattern attendancePattern})` with keys `home-team-section`, `home-shift-section`, and `home-attendance-pattern-section`.

- [ ] **Step 1: Write failing widget tests**

Test the following states using the public widget interface:

- Available demo-like data renders the three section keys, team detail sheet, shift label, heatmap rows, and percentage legend.
- Unavailable data renders the same three keys with truthful unavailable messages and no demo names or percentages.
- Available empty team and pattern data render explicit empty copy.
- A 320 px viewport at text scale 2.0 has no Flutter overflow exception and all three sections remain reachable by scrolling.

- [ ] **Step 2: Run the focused test and verify failure**

Run: `rtk flutter test test/features/dashboard/home_support_sections_test.dart --reporter compact`

Expected: FAIL because `HomeSupportSections` does not exist.

- [ ] **Step 3: Implement the shared widgets**

Create `HomeSupportSections` with the approved order: Tim Hari Ini, Shift berikutnya, Kehadiran. Map attendance levels to the existing blue palette inside presentation code. Use `AppSurfaceCard`, `AppIconTile`, `AppStatusChip`, semantics labels, wrapping text, and a root-navigator safe-area bottom sheet for team details. Unavailable and empty content must stay within the corresponding section card instead of replacing the page layout.

- [ ] **Step 4: Run the focused test and verify pass**

Run: `rtk flutter test test/features/dashboard/home_support_sections_test.dart --reporter compact`

Expected: PASS with no overflow exception.

- [ ] **Step 5: Commit the shared widgets**

```bash
rtk git add lib/features/dashboard/presentation/widgets/home_support_sections.dart test/features/dashboard/home_support_sections_test.dart
rtk git commit -m "feat(dashboard): add shared home support sections"
```

### Task 3: Remove the Beranda presentation-mode branch

**Files:**
- Modify: `lib/features/dashboard/presentation/screens/home_screen.dart`
- Modify: `lib/core/config/demo_mode.dart`
- Modify: `lib/demo/demo_overrides.dart`
- Modify: `lib/demo/demo_design_sections.dart`
- Modify: `test/features/dashboard/home_header_test.dart`
- Modify: `test/features/safety/no_demo_ui_test.dart`
- Test: `test/features/dashboard/home_presentation_parity_test.dart`

**Interfaces:**
- Consumes: `HomeSupportSections` from Task 2 and `dashboardControllerProvider`.
- Produces: A `HomeScreen` that never reads `demoHomeSectionsBuilderProvider` and renders `HomeSupportSections` directly from `DashboardSnapshot`.

- [ ] **Step 1: Write failing parity and architecture tests**

Create a parity test that pumps `HomeScreen` twice, once with an available demo-like snapshot and once with an unavailable production snapshot. Assert both renders contain the same ordered structural keys for header, attendance metrics, shortcuts, announcement, team, shift, attendance pattern, and leave balance. Extend the safety test to reject `demoHomeSectionsBuilderProvider` and any `lib/demo/` import in dashboard presentation.

- [ ] **Step 2: Run the focused tests and verify failure**

Run: `rtk flutter test test/features/dashboard/home_presentation_parity_test.dart test/features/safety/no_demo_ui_test.dart --reporter compact`

Expected: FAIL because `HomeScreen` still switches presentation through a demo builder.

- [ ] **Step 3: Wire the shared presentation**

Import `home_support_sections.dart` in `home_screen.dart`, remove the demo-mode import and builder lookup, and render `HomeSupportSections` from the current dashboard snapshot. Add stable structural keys to existing main sections only where required by the parity test. Remove `demoHomeSectionsBuilderProvider`, its override, and `DemoHomeSections`; retain `DemoAttendanceSummary` for the later Absensi stage.

- [ ] **Step 4: Run focused tests and verify pass**

Run: `rtk flutter test test/features/dashboard/home_presentation_parity_test.dart test/features/dashboard/home_header_test.dart test/features/safety/no_demo_ui_test.dart --reporter compact`

Expected: PASS.

- [ ] **Step 5: Commit the Beranda integration**

```bash
rtk git add lib/features/dashboard/presentation/screens/home_screen.dart lib/core/config/demo_mode.dart lib/demo/demo_overrides.dart lib/demo/demo_design_sections.dart test/features/dashboard/home_presentation_parity_test.dart test/features/dashboard/home_header_test.dart test/features/safety/no_demo_ui_test.dart
rtk git commit -m "refactor(dashboard): share home presentation across modes"
```

### Task 4: Beranda regression and visual verification

**Files:**
- Modify if visually approved: `test/goldens/stage4/home_fixture_light.png`
- Modify if visually approved: `test/goldens/stage4/home_fixture_dark.png`
- Modify if required: `test/stage4_golden_test.dart`
- Modify if required: `test/app/redesign_flow_test.dart`

**Interfaces:**
- Consumes: The shared `HomeScreen` completed in Task 3.
- Produces: Automated evidence that Beranda remains stable in both modes and at supported accessibility sizes.

- [ ] **Step 1: Run Beranda and architecture regression tests**

Run: `rtk flutter test test/features/dashboard test/features/safety/no_demo_ui_test.dart test/architecture --reporter compact`

Expected: PASS.

- [ ] **Step 2: Run golden tests without updating baselines**

Run: `rtk flutter test test/stage4_golden_test.dart --reporter compact`

Expected: PASS, or produce failure images for visual comparison. Update baselines only when the rendered change matches the approved HTML reference.

- [ ] **Step 3: Run repository quality gates**

Run:

```bash
rtk dart format --output=none --set-exit-if-changed lib test tool integration_test
rtk flutter analyze
rtk flutter test --coverage --reporter compact
```

Expected: formatting unchanged, analyzer reports no issues, and the full suite passes.

- [ ] **Step 4: Perform manual mode checks**

Run production configuration and demo mode separately on the available Android device. Verify identical section order, card geometry, navigation, scrolling, modal obstruction, and safe areas. Confirm content differs only because its repository data or capability differs.

- [ ] **Step 5: Commit only approved regression artifacts**

```bash
rtk git add test/stage4_golden_test.dart test/app/redesign_flow_test.dart test/goldens/stage4/home_fixture_light.png test/goldens/stage4/home_fixture_dark.png
rtk git commit -m "test(dashboard): verify shared home presentation"
```

Skip this commit when no regression artifact changed.
