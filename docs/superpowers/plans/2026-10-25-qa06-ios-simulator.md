# QA-06 iOS Simulator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add iOS simulator fixture integration and native screen-cover tests to macOS CI.

**Architecture:** Reuse RunnerTests, the existing Flutter integration entrypoint and the iOS CI job. A small Dart selector consumes simctl JSON and rejects unavailable/incompatible simulator inventories. No production behavior changes are planned.

**Tech Stack:** Dart/flutter_test, Swift/XCTest, Xcode simctl/xcodebuild, GitHub Actions.

**Spec:** docs/superpowers/specs/2026-10-25-qa06-ios-simulator-design.md

## Global Constraints

- Isolated source baseline: 8b939c4, tree identical to merged PR #1.
- Preserve main-workspace lockfile/Gradle/documentation changes; do not upgrade SDK/dependencies.
- CI pin remains 19946f91c8d9de18a4674460d015229cc0b2534f; use a temporary SDK checkout locally because the installed SDK changed.
- Fixture HTTPS only, logging and push disabled, no live credentials or business mutations.
- Native/simulator checks require macOS CI; Linux results never count as native PASS.

## Review Focus

- Empty/unavailable/too-old/iPad-only inventories must fail instead of silently skipping tests (Task 1).
- Runtime versions compare numerically and simulator UUID cannot inject shell content (Task 1).
- Cover is absent when disabled/active and removed on reactivation or disable (Task 2).
- Repeated state changes do not stack native covers; singleton is reset between tests (Task 2).
- Pipeline failures propagate while diagnostics still upload; no credentials or signing material enter tests (Task 3).

### Task 1: Simulator selection

**Files:** Create tool/select_ios_simulator.dart and test/tool/select_ios_simulator_test.dart.
**Interfaces:** selectIosSimulator(Map<String, dynamic> inventory) returns a record with udid, name, runtime and state; CLI reads JSON stdin and writes UUID/state stdout, metadata stderr. Minimum runtime 15.5 matches Runner.

- [x] Write tests for supported/newest numeric runtime, unavailable/malformed UUID, older runtime and empty/wrong-platform input.
- [x] Run focused test; verify RED before selector implementation.
- [x] Implement stdlib-only parser/CLI with nonzero exit on invalid input.
- [x] Run focused test and CLI valid/invalid JSON probes; verify GREEN.

### Task 2: Native cover characterization

**Files:** Modify ios/RunnerTests/RunnerTests.swift.
**Interfaces:** Existing SensitiveScreenProtection.shared, bind(window:), isEnabled, setSceneInactive(_:); assert actual UIWindow subviews.

- [x] Replace empty example with disabled, inactive/active, disable and repeated-state tests.
- [x] Reset singleton/window through existing APIs with defer; serialize XCTest execution.
- [ ] Run on macOS via Task 3; keep native execution PENDING until actual run evidence exists.
- [ ] If a defect appears, reproduce it before any production fix; do not add test-only production APIs.

### Task 3: Mandatory CI execution and evidence

**Files:** Modify .github/workflows/mobile-ci.yml and test/architecture/ci_workflow_test.dart; create report under docs/.
**Consumes:** Task 1 selector, Task 2 RunnerTests, existing integration_test/redesign_flow_test.dart.

- [x] Add failing YAML consumer checks for mandatory simulator step and always-upload diagnostics.
- [x] Preserve unsigned build; add boot/select, simulator debug build with safe defines, xcodebuild RunnerTests and Flutter fixture execution under pipefail.
- [x] Record Xcode/runtime/architecture; upload logs and xcresult even after failure.
- [x] Run focused tests, full suite, analyzer, format and diff/lockfile checks on pinned SDK.
- [x] Request one scoped review; report local/native evidence separately.
- [ ] Publish only with authorization; remote PR may require user action due prior 403. Do not merge automatically.

## Execution ledger

- Ruling: execute inline as requested; no additional design/plan approval pause because the user explicitly authorized implementation of this bounded design.
- Ruling: characterize existing native behavior without claiming RED/GREEN execution on Linux; native acceptance remains pending until CI runs.
- Task completion requires observed results, not merely checked boxes or YAML presence.
