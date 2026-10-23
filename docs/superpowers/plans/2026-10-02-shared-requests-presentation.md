# Shared Requests Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Pengajuan use one production-quality widget tree in demo and production while preserving local demo leave/permission persistence and remote production API behavior.

**Architecture:** Keep `RequestsScreen`, `RequestPageQuery`, and `RequestRepository` as the shared presentation and data boundary. Remove demo screen injection, render repository-backed leave and permission records through the same sections, and use neutral copy wherever persistence may be local or remote. Overtime and reimbursement remain navigation capabilities owned by their existing features rather than fabricated request-list records.

**Tech Stack:** Flutter, Dart, Riverpod, `flutter_test`

**Spec:** `docs/superpowers/specs/2026-09-30-shared-presentation-demo-production-design.md`

## Global Constraints

- Demo and production must render the same Pengajuan widget tree and section order.
- `DEMO_MODE` may configure repositories and the banner, but not Pengajuan layout or sections.
- Production must never receive demo records, local fallback data, or fabricated overtime/reimbursement history.
- Demo leave and permission creation, listing, detail, and cancellation remain local and persistent through `DemoRequests` and `DemoStore`.
- Preserve the current uncommitted Pengajuan redesign as the visual baseline and stage no unrelated worktree changes.
- Keep status-bar safe areas, 44 dp controls, 320 dp/200% text reflow, bottom clearance, and modal obstruction behavior.
- Add no package, new request kind, or speculative presentation abstraction.
- Prefix repository shell commands with `rtk`.

## Review Focus

- A demo repository with seeded leave and permission records renders the same structural sections as a production repository fixture.
- A paginated response never presents current-page pending/completed counts as global totals.
- Loading or failure in either leave or permission data produces an explicit shared state without leaking partial or demo-only records.
- Local create/cancel success copy does not falsely claim a server write, while production remains accurate.
- Category capsules and action cards remain reachable without overflow at 320 dp and 200% text.

---

### Task 1: Remove demo presentation injection

**Files:**
- Modify: `lib/core/config/demo_mode.dart`
- Modify: `lib/demo/demo_overrides.dart`
- Delete: `lib/demo/demo_requests_screen.dart`
- Modify: `lib/features/self_service/presentation/screens/requests_screen.dart`
- Create: `test/features/self_service/requests_shared_screen_test.dart`

**Interfaces:**
- Consumes: `requestRepositoryProvider`, `requestPageProvider(RequestPageQuery)`, and the current Pengajuan redesign already present in `RequestsScreen`.
- Produces: one shared screen with keys `requests-header`, `requests-summary-actions`, `requests-category-filters`, `requests-history-header`, and `requests-history-content`.

- [ ] **Step 1: Write the failing shared-screen test**

Pump `RequestsScreen` with `demoOverrides(DemoStore)` and assert the five structural keys exist in order, seeded leave/permission records render, and `DemoRequestsScreen` is not selected. Add a production empty-repository case that asserts the same keys.

- [ ] **Step 2: Run the focused test and verify failure**

Run: `rtk flutter test test/features/self_service/requests_shared_screen_test.dart --reporter compact`

Expected: FAIL because demo still returns `DemoRequestsScreen` and the structural keys do not exist.

- [ ] **Step 3: Wire the shared presentation**

Remove `demoRequestsBuilderProvider`, its demo override/import, and the early builder return from `RequestsScreen`. Delete `demo_requests_screen.dart`. Add the five stable keys to the existing redesigned sections without changing repository contracts.

- [ ] **Step 4: Run the focused test and verify pass**

Run: `rtk flutter test test/features/self_service/requests_shared_screen_test.dart --reporter compact`

Expected: PASS.

- [ ] **Step 5: Commit shared presentation wiring**

```bash
rtk git add lib/core/config/demo_mode.dart lib/demo/demo_overrides.dart lib/demo/demo_requests_screen.dart lib/features/self_service/presentation/screens/requests_screen.dart test/features/self_service/requests_shared_screen_test.dart
rtk git commit -m "refactor(requests): share presentation across modes"
```

### Task 2: Keep counts, actions, and persistence copy truthful

**Files:**
- Modify: `lib/features/self_service/presentation/screens/requests_screen.dart`
- Modify: `lib/features/self_service/presentation/screens/request_form_screen.dart`
- Modify: `test/features/self_service/requests_shared_screen_test.dart`
- Modify: `test/demo/requests_safe_area_test.dart`

**Interfaces:**
- Consumes: the structural keys and shared `RequestsScreen` from Task 1.
- Produces: honest full-page versus paginated summaries, repository-neutral success/detail copy, and local demo behavior using real leave/permission records only.

- [ ] **Step 1: Write failing behavior tests**

Assert a single-page demo response shows accurate pending/completed counts; a multi-page production fixture labels counts as current-page data; local records never claim they were saved, cancelled, or calculated by the server; and the Lembur/Reimburse capsules navigate without adding example request cards.

- [ ] **Step 2: Run the focused tests and verify failure**

Run: `rtk flutter test test/features/self_service/requests_shared_screen_test.dart test/demo/requests_safe_area_test.dart --reporter compact`

Expected: FAIL because page counts and copy still imply global/server state and demo tests still expect obsolete example records.

- [ ] **Step 3: Implement truthful shared behavior**

For `totalPages <= 1`, render actual pending/completed counts. For paginated data, label the total and page while keeping the pending action explicitly scoped to the current page. Replace storage-agnostic “server” success/detail text with neutral workflow copy. Update demo regression expectations to seeded leave/permission data and remove example-only assertions.

- [ ] **Step 4: Run the focused tests and verify pass**

Run: `rtk flutter test test/features/self_service/requests_shared_screen_test.dart test/demo/requests_safe_area_test.dart --reporter compact`

Expected: PASS.

- [ ] **Step 5: Commit truthful behavior**

```bash
rtk git add lib/features/self_service/presentation/screens/requests_screen.dart lib/features/self_service/presentation/screens/request_form_screen.dart test/features/self_service/requests_shared_screen_test.dart test/demo/requests_safe_area_test.dart
rtk git commit -m "fix(requests): keep shared workflow states truthful"
```

### Task 3: Lock parity, architecture, and responsive behavior

**Files:**
- Create: `test/features/self_service/requests_presentation_parity_test.dart`
- Modify: `test/architecture/dependency_rules_test.dart`
- Modify: `test/features/safety/no_demo_ui_test.dart` only when task-owned assertions can be staged without absorbing unrelated edits
- Modify if visually approved: `test/goldens/stage5/requests_fixture_light_320_text200.png`
- Modify if visually approved: `test/goldens/stage5/requests_fixture_dark_320_text200.png`

**Interfaces:**
- Consumes: the shared structural keys from Task 1 and truthful state rules from Task 2.
- Produces: automated evidence that demo and production share Pengajuan composition and production cannot select demo presentation.

- [ ] **Step 1: Write parity and architecture tests**

Pump shared Pengajuan with demo and production repositories and assert the same ordered structural keys. Reject `demoRequestsBuilderProvider`, imports from `lib/demo/`, and `demoModeProvider` reads inside self-service presentation. Verify production contains no demo labels or records.

- [ ] **Step 2: Run focused parity tests**

Run: `rtk flutter test test/features/self_service/requests_presentation_parity_test.dart test/architecture/dependency_rules_test.dart test/features/safety/no_demo_ui_test.dart --reporter compact`

Expected: PASS after Tasks 1 and 2.

- [ ] **Step 3: Run visual and accessibility regression**

Run: `rtk flutter test test/demo/requests_safe_area_test.dart test/stage5_golden_test.dart test/stage5_resilience_test.dart --reporter compact`

Expected: PASS without golden updates, or generate failures for comparison. Update golden artifacts only when the shared render matches the approved HTML reference.

- [ ] **Step 4: Run repository quality gates**

```bash
rtk dart format --output=none --set-exit-if-changed lib test tool integration_test
rtk flutter analyze
rtk flutter test --coverage --reporter compact
```

Expected: formatting unchanged, analyzer reports no issues, and the full suite passes.

- [ ] **Step 5: Perform manual mode checks when Android is available**

Run production and `--dart-define=DEMO_MODE=true` separately. Verify identical section order, safe areas, filters, scrolling, creation menu, detail/cancel modal obstruction, production remote behavior, and demo local persistence. Record any authentication or locked-device limitation rather than claiming a manual pass.

- [ ] **Step 6: Commit parity artifacts**

```bash
rtk git add test/features/self_service/requests_presentation_parity_test.dart test/architecture/dependency_rules_test.dart
rtk git commit -m "test(requests): verify shared presentation parity"
```

Stage only task-owned safety or golden changes that were explicitly reviewed.
