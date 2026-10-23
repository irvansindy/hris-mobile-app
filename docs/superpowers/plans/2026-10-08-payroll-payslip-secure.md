# Payroll dan Payslip Aman Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menyediakan alur employee payslip yang aman dari daftar terkunci sampai detail dan PDF, dengan token unlock hanya di memori dan penguncian ulang saat aplikasi masuk background.

**Architecture:** Feature `payroll` menjadi vertical slice dengan domain model, repository yang dapat ditukar, controller Riverpod, dan shared presentation. `PayslipUnlockVault` terikat identitas sesi dan tidak menjadi interceptor global; lifecycle serta platform privacy protection membersihkan konten sensitif secara deterministik.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, GoRouter, pdfrx 2.6.5, Android `FLAG_SECURE`, iOS privacy overlay, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-08-payroll-payslip-secure-design.md`

## Global Constraints

- Hanya gunakan employee PIN flow dan header `X-Payslip-Unlock`; jalur admin berada di luar scope.
- PIN tepat enam digit dan tidak pernah disimpan atau dicatat.
- Unlock token, nominal, dan byte PDF hanya hidup di memori serta dibersihkan pada `inactive`, `paused`, `detached`, logout, pergantian identitas/company, expiry, atau `PAYSLIP_UNLOCK_INVALID`.
- Daftar periode tidak boleh memiliki field nominal.
- PDF maksimum 5 MB dan dirender dari `Uint8List`; tidak ada URL publik, export, atau cache permanen milik aplikasi.
- Demo dan production memakai screen/controller yang sama dengan repository berbeda.
- UI mengikuti handoff yang sudah disetujui dengan ENERGY 1, RHYTHM 2, MOTION 1 serta seluruh aturan antislop aktif.

## Review Focus

- Timestamp expiry/lockout invalid atau berbeda zona waktu harus gagal aman dan meminta refresh, bukan membuka konten.
- Response detail dengan decimal berbentuk string/number dan komponen asing harus tetap dapat ditampilkan tanpa menebak arti.
- Pergantian user, employee, atau company ketika request detail masih berjalan tidak boleh menerbitkan nominal lama.
- PDF dengan content type salah, magic bytes salah, kosong, atau melebihi 5 MB harus ditolak sebelum viewer.
- Transisi lifecycle cepat `inactive → resumed` harus tetap mengunci ulang dan tidak memulihkan vault lama.

---

### Task 1: Domain model dan unlock vault in-memory

**Files:**
- Create: `lib/features/payroll/domain/payroll_models.dart`
- Create: `lib/features/payroll/domain/payroll_repository.dart`
- Create: `lib/features/payroll/domain/payslip_unlock_vault.dart`
- Test: `test/features/payroll/payslip_unlock_vault_test.dart`

**Interfaces:**
- Produces: `PayslipSummary`, `PayslipPinStatus`, `PayslipUnlockGrant`, `PayslipDetail`, `PayslipComponent`, `PayslipPdf`, `PayrollRepository`, dan `PayslipUnlockVault`.
- `PayslipUnlockVault.read(RequestContext, DateTime)` hanya mengembalikan token yang belum expiry dan fingerprint-nya cocok.

- [ ] Tulis test gagal untuk store/read, expiry, clear, identity mismatch, timestamp invalid, dan transisi lifecycle cepat.
- [ ] Jalankan `rtk flutter test test/features/payroll/payslip_unlock_vault_test.dart` dan pastikan RED karena API belum tersedia.
- [ ] Implementasikan model immutable, kontrak repository, dan vault memory-only minimal.
- [ ] Jalankan test yang sama sampai GREEN.
- [ ] Commit hanya file Task 1 dengan pesan `feat(payroll): add in-memory payslip unlock domain`.

### Task 2: Kontrak API employee payslip

**Files:**
- Create: `lib/features/payroll/data/dio_payroll_repository.dart`
- Create: `lib/features/payroll/payroll_dependencies.dart`
- Modify: `lib/core/network/api_error_mapper.dart`
- Test: `test/features/payroll/payroll_api_contract_test.dart`
- Test: `test/core/api_error_mapper_test.dart`

**Interfaces:**
- Consumes: domain interface dan models dari Task 1, `featureDioProvider`, `featureSessionProvider`, serta `RequestContext.hasPermission`.
- Produces: `DioPayrollRepository` dan `payrollRepositoryProvider`.

- [ ] Tulis contract tests gagal untuk enam endpoint employee, body PIN/password, header detail/PDF, daftar tanpa nominal, decimal string/number, komponen asing, session berubah saat request, dan semua error code payroll.
- [ ] Tulis test gagal untuk PDF kosong, non-PDF magic bytes, content type salah, dan ukuran lebih dari 5 MB.
- [ ] Jalankan `rtk flutter test test/features/payroll/payroll_api_contract_test.dart test/core/api_error_mapper_test.dart` dan verifikasi RED.
- [ ] Implementasikan mapping envelope/binary yang ketat; mutasi tidak memakai automatic retry dan header unlock hanya dipasang per request detail/PDF.
- [ ] Jalankan kedua test sampai GREEN.
- [ ] Commit file Task 2 dengan pesan `feat(payroll): integrate employee payslip API`.

### Task 3: Controller, lifecycle, dan isolasi sesi

**Files:**
- Create: `lib/features/payroll/payroll_providers.dart`
- Create: `lib/features/payroll/presentation/controllers/payroll_controller.dart`
- Create: `lib/features/payroll/presentation/controllers/payroll_lifecycle_lock.dart`
- Modify: `lib/features/authentication/presentation/controllers/auth_controller.dart`
- Test: `test/features/payroll/payroll_controller_test.dart`
- Test: `test/core/session_isolation_test.dart`

**Interfaces:**
- Consumes: repository, vault, request context, dan feature session dari Task 1-2.
- Produces: list/status/controller providers, `unlock(pin)`, `setPin(currentPassword, pin)`, `loadDetail(id)`, `loadPdf(id)`, dan `lock()`.

- [ ] Tulis test gagal untuk setup PIN, unlock, lockout, expired/invalid unlock, clear saat background/logout/account switch, invalidasi detail/PDF, dan late response setelah identity switch.
- [ ] Jalankan `rtk flutter test test/features/payroll/payroll_controller_test.dart test/core/session_isolation_test.dart` dan verifikasi RED.
- [ ] Implementasikan controller dan lifecycle observer minimal; setiap clear menghapus grant serta state sensitif.
- [ ] Jalankan test sampai GREEN.
- [ ] Commit file Task 3 dengan pesan `feat(payroll): lock payslip data with app lifecycle`.

### Task 4: Shared payroll presentation dan demo repository

**Files:**
- Create: `lib/features/payroll/presentation/screens/payroll_screen.dart`
- Create: `lib/features/payroll/presentation/screens/payslip_detail_screen.dart`
- Create: `lib/demo/demo_payroll_repository.dart`
- Modify: `lib/demo/demo_overrides.dart`
- Modify: `lib/app/router/app_router.dart`
- Modify: `lib/app/shell/quick_action_capabilities.dart`
- Modify: `lib/features/profile/presentation/screens/profile_screen.dart`
- Test: `test/features/payroll/payroll_screen_test.dart`
- Test: `test/features/payroll/payroll_presentation_parity_test.dart`
- Test: `test/app/quick_action_capabilities_test.dart`

**Interfaces:**
- Consumes: providers/controller Task 3.
- Produces: route `/payroll`, `/payroll/:id`, daftar terkunci, setup PIN, unlock, lockout, detail, error/empty/retry, dan explicit lock action.

- [ ] Tulis widget tests gagal untuk permission, daftar aman, setup PIN validation, unlock, lockout, komponen asing, error, expiry, dan tidak adanya bottom navigation pada route sensitif.
- [ ] Tulis parity test gagal yang membuktikan demo/production memakai komposisi screen dan controller yang sama.
- [ ] Jalankan focused tests dan verifikasi RED.
- [ ] Implementasikan shared UI mengikuti komponen/theme yang ada; aktifkan quick action hanya untuk `payroll:read`.
- [ ] Implementasikan demo repository dengan label demo, expiry pendek, lockout, detail, dan PDF fixture in-memory.
- [ ] Jalankan focused tests sampai GREEN.
- [ ] Commit file Task 4 dengan pesan `feat(payroll): add shared secure payslip flow`.

### Task 5: Viewer PDF dan proteksi layar platform

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `lib/core/security/sensitive_screen.dart`
- Create: `lib/features/payroll/presentation/screens/payslip_pdf_screen.dart`
- Modify: `android/app/src/main/kotlin/com/example/hrm_app/MainActivity.kt`
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `ios/Runner/SceneDelegate.swift`
- Test: `test/core/sensitive_screen_test.dart`
- Test: `test/features/payroll/payslip_pdf_screen_test.dart`

**Interfaces:**
- Produces: `SensitiveScreenController.enable()/disable()` via method channel dan `PayslipPdfScreen(Uint8List bytes, String sourceName)` memakai `PdfViewer.data`.

- [ ] Tambahkan failing channel/widget tests untuk enable/disable, dispose, lifecycle overlay, invalid bytes, loading, dan viewer memory source.
- [ ] Jalankan focused tests dan verifikasi RED.
- [ ] Tambahkan `pdfrx: ^2.6.5`, implementasikan `FLAG_SECURE` Android serta privacy overlay/capture response iOS.
- [ ] Implementasikan PDF viewer tanpa export dan tanpa path file aplikasi.
- [ ] Jalankan focused tests sampai GREEN serta build Android debug.
- [ ] Commit file Task 5 dengan pesan `feat(payroll): protect and render payslip PDF`.

### Task 6: Safety, golden, dokumentasi, dan full verification

**Files:**
- Create: `test/features/payroll/payroll_safety_test.dart`
- Create: `test/payroll_golden_test.dart`
- Create: `test/goldens/payroll/`
- Modify: `test/stage5_resilience_test.dart`
- Modify: `docs/Breakdown Task Go Live HRIS Mobile App.md`
- Create: `docs/Tahap 6 Payroll dan Payslip Aman.md`

**Interfaces:**
- Consumes: seluruh feature Tasks 1-5.
- Produces: bukti keamanan, visual, CI, dan daftar blocker live.

- [ ] Tulis safety tests gagal untuk token/PIN/nominal pada storage/log, penggunaan header admin, route tanpa permission, dan stale state.
- [ ] Tambahkan golden/resilience cases light/dark 320dp text 200% untuk list, setup, unlock, lockout, detail, dan PDF error.
- [ ] Jalankan test baru, perbarui golden secara eksplisit, inspeksi hasil, lalu pastikan GREEN.
- [ ] Jalankan `rtk dart format --output=none --set-exit-if-changed lib test tool integration_test`.
- [ ] Jalankan `rtk flutter analyze`.
- [ ] Jalankan `rtk flutter test` dan pastikan seluruh suite hijau.
- [ ] Jalankan `rtk flutter build apk --debug` serta `rtk git diff --check`.
- [ ] Catat hasil dan blocker staging/real-device pada report serta roadmap.
- [ ] Commit file Task 6 dengan pesan `test(payroll): verify secure payslip release gates`.
