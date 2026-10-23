# Shared Presentation for Demo and Production

## Status

Proposed for implementation after user review. This specification replaces mode-specific screen composition with one presentation layer backed by interchangeable repositories.

## Objective

Demo and production must render the same authenticated application interface. Layout, components, navigation, typography, spacing, modal behavior, loading states, empty states, and error states must not depend on `DEMO_MODE`. The mode may change data sources, supported capabilities, and the visible `DEMO` banner only.

Success means a UI change to an authenticated screen is implemented once and appears in both modes without copying widgets or maintaining a second screen.

## Scope

The parity audit and refactor cover:

- Beranda and its attendance, announcement, team, shift, attendance-history, and leave-balance sections.
- Absensi, including summaries, history, location status, clock-in/out, and Face ID entry points.
- Pengajuan, filters, history, pagination, creation actions, and detail sheets.
- Kalender, Profil, Notifikasi, Approval, ESS, account security, and related forms.
- The shared shell, bottom navigation, quick actions, safe areas, dialogs, and bottom sheets.

Authentication and release configuration are not redesigned. Backend contracts, demo persistence, face matching algorithms, and the visual reference approved in the existing redesign work remain unchanged.

## Architecture

### Shared presentation

Each route owns one production-quality screen and one widget tree. Screens consume domain entities and explicit presentation state from Riverpod controllers/providers. They do not import `lib/demo/`, select a layout from `demoModeProvider`, or accept a demo-only `WidgetBuilder`.

Reusable sections may be extracted under the owning feature's `presentation/widgets/` directory when they have a clear input model and callbacks. These widgets remain data-source agnostic.

### Interchangeable data layer

Repository providers remain the switching boundary:

- Production overrides use remote data sources and the configured API client.
- Demo overrides use local repositories, `DemoStore`, and secure local Face ID storage.
- Both implementations return the same domain entities and failure semantics expected by shared controllers.

`DEMO_MODE` may configure repository overrides, offline adapters, demo authentication, the demo banner, and demo-only capabilities. It must not replace screens or screen sections.

### Capabilities

Availability is represented as data rather than alternate layouts. A capability model or existing permission/context providers determine whether an action is enabled, hidden, or explained as unavailable. Production never receives fabricated values. Demo data remains clearly labelled where content itself is simulated.

## Required Refactor

Remove presentation injection through:

- `demoHomeSectionsBuilderProvider`
- `demoAttendanceSummaryBuilderProvider`
- `demoRequestsBuilderProvider`

Replace `DemoHomeSections`, `DemoAttendanceSummary`, and `DemoRequestsScreen` with shared sections driven by domain view models. Demo repositories must supply the values needed by those models. `demoToolsBuilderProvider` may remain temporarily because it exposes an explicitly demo-only testing tool from Profil, but it must not alter the profile layout. If the same Face ID management action is required in production, expose it through a shared capability and shared row component.

## Data and State Flow

1. The active mode configures repository providers during bootstrap.
2. Shared controllers request domain data without checking the mode.
3. Shared screens render loading, data, empty, permission, offline, and error states.
4. User actions call shared controller/repository contracts.
5. Demo repositories persist supported actions locally; production repositories call the API.
6. Refresh and session changes invalidate the same providers in both modes.

Mode-specific text is allowed only when it describes a real behavioral distinction, such as local demo persistence or unavailable server verification.

## Error Handling and Safety

- Production must never fall back to demo repositories or sample records after an API failure.
- Demo must remain offline and must not send data to the production API.
- Missing capabilities produce an explicit disabled or unavailable state, not a non-functional button.
- Session isolation, token handling, Face ID storage, and logout cleanup remain intact.
- Bottom navigation and floating actions must be obscured or dismissed when modal routes and bottom sheets are active.

## Testing Strategy

Add tests at three levels:

1. **Architecture:** fail when feature presentation imports `lib/demo/` or when demo overrides inject screen builders.
2. **Parity widgets:** render key screens with production and demo repository fixtures, then assert the same structural keys, section order, navigation, safe-area behavior, and interaction targets.
3. **Behavior:** retain separate assertions for data content and side effects, including remote API calls in production and local persistence in demo.

Update golden images only after confirming that changes match the approved HTML design. Run formatting, `flutter analyze`, the full Flutter test suite with coverage, and the existing release-safety tests. Perform manual checks on a narrow emulator and a real device for both modes.

## Delivery Order

1. Introduce shared presentation models and parity/architecture tests.
2. Unify Beranda.
3. Unify Absensi.
4. Unify Pengajuan.
5. Audit and align Kalender, Profil, and secondary feature screens.
6. Remove obsolete demo presentation files/providers.
7. Run automated and real-device regression checks in both modes.

The refactor is complete only when no authenticated screen chooses its visual structure based on demo mode and both modes pass the same presentation regression suite.
