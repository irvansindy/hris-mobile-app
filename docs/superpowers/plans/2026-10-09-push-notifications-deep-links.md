# Push Notification dan Deep Link Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menguji registration, inbox, dan routing push yang terisolasi per sesi melalui dummy lokal sebelum Firebase partner tersedia.

**Architecture:** Pertahankan shared notification screen dan mapper route. Adapter push serta repository registration dapat ditukar; coordinator app-scoped menserialkan operasi dan menolak callback sesi lama. Mode dummy memakai event dan registration in-memory, sementara repository Dio diverifikasi melalui mocked HTTP.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, GoRouter, SharedPreferences, flutter_test; dependency Firebase yang ada belum diaktifkan.

**Spec:** `docs/superpowers/specs/2026-10-09-push-notifications-deep-links-design.md`, termasuk revisi Firebase dummy.

## Global Constraints

- Prefix shell dengan `rtk`; gunakan `apply_patch`; pertahankan perubahan tahap sebelumnya yang belum di-commit.
- Tidak menambah key/config Firebase palsu, dependency baru, event bus, polling, persistent message queue, atau local notification plugin.
- `PUSH_MODE=disabled` default; `PUSH_MODE=dummy` hanya debug; demo memakai dummy tanpa koneksi Firebase.
- Token contoh tidak boleh mencapai endpoint backend. Token/payload tidak dipersist atau dilog.
- Inbox menggunakan `page` dan limit tetap 50 (server maksimum 100).
- Lookup tap hanya halaman pertama server dengan limit 50; ID tidak ditemukan membuka `/notifications`.
- Allowlist awal: attendance, leave/leave_request, permission_request, work_calendar. Payslip tetap membutuhkan PIN; tidak ditambah ke allowlist push awal.
- Fake test tidak membuktikan delivery OS, cleanup server saat offline, APNs, atau Firebase nyata. Semua tetap gate live.
- Implementasi native/inline pada checkout aktif; stage exact files/hunks per task, bukan `git add -A`.

## Review Focus

- Load-more gagal setelah halaman pertama: item lama dan page tetap tersedia untuk retry (Task 1).
- Token berubah saat register belum selesai: token terakhir direkonsiliasi tanpa response lama mengaktifkan sesi baru (Task 3).
- Logout offline lalu login akun lain: token/binding lama tidak digunakan kembali oleh dummy coordinator (Task 3).
- Tap initial saat auth restore belum selesai: tidak bernavigasi sebelum server inbox sesi aktif diperiksa (Task 4).
- Duplicate tap tanpa message ID: gunakan notification ID; payload tanpa kedua ID hanya membuka inbox sekali per event batch (Task 4).

## File Map

- `lib/features/notifications/domain/entities/notification_item.dart`: page result dan state inbox.
- `lib/features/notifications/domain/repositories/notification_repository.dart`: signature paginated inbox.
- `lib/features/notifications/data/notification_repository_impl.dart`: pemetaan metadata page.
- `lib/features/notifications/notification_providers.dart`: refresh/load-more per page.
- `lib/features/notifications/push/push_registration.dart`: command, interface registry, Dio registry, installation ID.
- `lib/features/notifications/push/push_adapter.dart`: event/permission types, interface, disabled/dummy adapter.
- `lib/features/notifications/push/push_coordinator.dart`: serialized binding dan session-aware event handling.
- `lib/features/notifications/push/push_providers.dart`: dependency selection dan lifecycle app.
- `lib/app/router/notification_route.dart`: tap resolution memakai inbox terpercaya dan mapper existing.
- `lib/features/notifications/presentation/widgets/push_status_panel.dart`: status dan simulator debug, dipakai screen existing.
- `lib/demo/demo_secondary_repositories.dart`: page API demo dan fake registry; fixtures/test implementer mengikuti interface baru.
- `lib/main.dart`, authentication cleaner/controller, dan `lib/core/config/app_config.dart`: bootstrap/config/cleanup terbatas.
- `test/features/notifications/`: contract, coordinator, adapter, resolver, dan simulator tests.

---

### Task 1: Pagination Inbox dan Kontrak Registration

**Files:** Modify notification entity/repository/data/providers, demo repository, serta semua implementer yang ditemukan dengan `rtk rg 'implements NotificationRepository|Future<List<NotificationItem>> load' lib test`. Create `push/push_registration.dart`; test `test/features/notifications/push_registration_test.dart`, `notification_pagination_test.dart`; update `notification_test.dart`.

**Interfaces:**
- Produce `NotificationPage({required List<NotificationItem> items, required int page, required int totalPages, required int total})`.
- Ganti `NotificationRepository.load` dengan `Future<NotificationPage> load({int page = 1, int limit = 50})`.
- Produce `DeviceRegistration({required String installationId, required String platform, required String token, required String idempotencyKey, String? appVersion})`; provider wire selalu `FCM`. Key adalah header, bukan field JSON.
- Produce `DeviceRegistrationRepository.register(DeviceRegistration registration)` dan `unregister(String installationId, {required String idempotencyKey})`, keduanya `Future<void>`.
- Produce `InstallationIdentity(SharedPreferences preferences, String namespace).getOrCreate(): String`; random aman, ID hex 32 karakter.

- [ ] Tulis failing tests: page 1/2 dengan limit 50, metadata malformed ditolak, duplicate ID antarpages dedup, page-2 error mempertahankan page-1 dan retry meminta page 2 lagi.
- [ ] Tulis failing contract tests: register 201 mengirim empat required fields dan `provider: FCM`, DELETE 200 membawa JSON installation ID; installation ID 7/201 karakter serta token 19/4097 ditolak sebelum network; ID stabil sesudah restart/logout dan berbeda namespace.
- [ ] Jalankan `rtk flutter test test/features/notifications/notification_pagination_test.dart test/features/notifications/push_registration_test.dart`; pastikan failure menunjuk perilaku yang belum tersedia.
- [ ] Implementasikan interfaces di atas. Pahami shape `meta` OpenAPI sebelum mapping; jangan menebak total dari panjang list. Ikuti pola `Options(headers: {'Idempotency-Key': command.idempotencyKey})` repository existing. Invalid load-more tidak mengganti state lama dengan AsyncError kosong.
- [ ] Jalankan `rtk flutter test test/features/notifications test/features/secondary_presentation_parity_test.dart`; hasil harus PASS, fixture/demo mengikuti kontrak page yang sama.
- [ ] Commit exact files: `feat(notifications): add paginated inbox and device registration contract`.

### Task 2: Adapter Dummy dan Konfigurasi Debug

**Files:** Create `push/push_adapter.dart`, `push/push_providers.dart`, `test/features/notifications/push_adapter_test.dart`; modify `lib/core/config/app_config.dart`, config tests, demo overrides bila diperlukan.

**Interfaces:**
- Produce `PushMode {disabled, dummy}` dan `PushPermission {unknown, authorized, denied}`.
- Produce `PushEvent({String? messageId, String? notificationId, required PushEventKind kind})`, kind foreground/opened/initial.
- Produce `PushAdapter`: `Future<PushPermission> requestPermission()`, `Future<String?> getToken()`, `Stream<String> get tokenChanges`, `Stream<PushEvent> get events`, `Future<void> deleteToken()`, `Future<void> dispose()`.
- Dummy menyediakan `emit(PushEvent)`, `rotateToken()`, `setPermission(PushPermission)` dan registry in-memory dengan switch failure yang hanya dipakai simulator/test.

- [ ] Tulis failing tests: default disabled; debug dummy tersedia; profile/release menolak dummy; demo override memilih dummy tanpa Firebase method call. Disabled mengembalikan null token, denied tidak meminta permission berulang, dispose menutup streams.
- [ ] Jalankan `rtk flutter test test/features/notifications/push_adapter_test.dart test/core/app_config_test.dart`; failure harus terkait mode/adapter yang belum ada.
- [ ] Implementasikan types dan adapter minimal. `PushEvent` tidak membawa title/body/URL. Mode dummy tidak membaca environment Firebase dan tidak mengirim token ke Dio registry; production mode disabled tidak menjalankan service push.
- [ ] Jalankan tests Task 2 dan safety release existing; hasil PASS. Catat bahwa Android/iOS permission OS belum diuji.
- [ ] Commit exact files: `feat(notifications): add debug-only dummy push adapter`.

### Task 3: Coordinator Registration dan Session Cleanup

**Files:** Create `push/push_coordinator.dart`, `test/features/notifications/push_coordinator_test.dart`; modify push providers, bootstrap `lib/main.dart`, dan authentication cleaner/controller hanya pada hook terkait.

**Interfaces:**
- Consume adapter, registry, installation identity Task 1/2 dan `FeatureSession` existing.
- Produce `PushCoordinator` dengan `Future<void> bind(FeatureSession session)`, `Future<void> retry()`, `Future<void> unbind()`, `Future<void> dispose()`.
- Produce state `PushStatus {disabled, denied, registering, simulated, failed}` dan status provider. `simulated` tidak boleh ditulis sebagai delivery/registration Firebase nyata.
- App owns coordinator; setiap bind mendapatkan registry bound ke identitas lama/current yang tepat. Dummy registry tidak memakai credential; future Dio binding wajib menangkap konteks lama sebelum invalidasi.

- [ ] Tulis failing tests memakai completer: rotate selama POST tertunda hanya token terakhir menjadi binding aktif; response register A sesudah switch B tidak mengaktifkan A; unregister A selesai sebelum register B; logout failure tetap membersihkan state/pending event dan menghapus token dummy.
- [ ] Tulis tests permission denied serta adapter/registry failure tidak memblokir login/inbox; retry pengguna tidak membuat loop; disable/dispose melepas subscriptions. Dummy account switch menghasilkan token baru dan tidak mengirim contoh lewat Dio.
- [ ] Jalankan `rtk flutter test test/features/notifications/push_coordinator_test.dart`; amati RED.
- [ ] Implementasikan coordinator menggunakan satu serialized future chain dan session generation. Gunakan `Uuid().v4` dependency existing untuk key per operasi; explicit retry mempertahankan command/key, token rotation menggantinya. Saat unbind segera nonaktifkan event/clear UI state; bounded cleanup memakai timeout network configured, failure tidak memblokir logout tanpa batas. Jangan tambahkan credential snapshot ke preferences atau logger.
- [ ] Jalankan tests coordinator, `test/features/authentication/`, `test/core/session_isolation_test.dart`; hasil PASS. Explicit retry/status menyatakan simulasi lokal.
- [ ] Commit exact hunks: `feat(notifications): coordinate session-safe dummy push lifecycle`.

### Task 4: Tap Resolver dan Simulator pada Inbox

**Files:** Modify `lib/app/router/notification_route.dart`, notification screen, push providers/coordinator. Create `presentation/widgets/push_status_panel.dart`, `test/features/notifications/push_route_test.dart`, `push_simulator_test.dart`; update notification route tests existing.

**Interfaces:**
- Produce `Future<String> resolvePushLocation(PushEvent event, NotificationRepository repository, bool Function() isCurrent)`. Fetch page 1/limit 50, cari notification ID, lalu gunakan `notificationResourceLocation`; fallback `/notifications`.
- Coordinator menyerahkan opened/initial event ke router hanya setelah auth selesai dan session current. Foreground menginvalidasi unread/inbox aktif tanpa navigasi. Hook app tidak membuat provider inbox aktif terus-menerus.
- Panel debug berlabel `Simulasi push lokal`; controls event, rotate, denied, failure, retry. Mode disabled menampilkan status nonaktif tanpa simulator.

- [ ] Tulis failing tests: initial sebelum auth tidak bernavigasi; item valid current membuka mapper existing; item tidak ada, server error, unknown resource, payload URL, dan session berubah saat lookup menuju inbox atau dibuang tanpa resource navigation.
- [ ] Tulis duplicate tests messageId/notificationId, initial+opened, event setelah logout, dan user login baru hanya mendapatkan lookup baru tanpa item/payload lama. Push payslip tidak melewati PIN. Frame target simulator initial ditandai simulasi, bukan kill/relaunch OS.
- [ ] Jalankan `rtk flutter test test/features/notifications/push_route_test.dart test/features/notifications/push_simulator_test.dart`; amati RED.
- [ ] Implementasikan resolver dan router bridge dengan pending intent memori satu slot, dedup cache maksimum 100 key per sesi. Jangan mempersist payload, menjelajah seluruh halaman, atau membuat GET detail notifikasi yang tidak ada. Simulator hanya mengakses dummy adapter/registry.
- [ ] Jalankan tests Task 4, notification screen, router, parity/resilience; pastikan panel sesuai shared theme pada 320dp/text 200% dan golden berubah hanya ketika sengaja.
- [ ] Commit exact files/hunks: `feat(notifications): resolve trusted push taps and expose local simulator`.

### Task 5: Final Review, Regression, dan Report Gate Live

**Files:** Create `docs/Tahap 6 Push Notification dan Deep Link.md`, `docs/Tahap 6 Acceptance Push Live Tertunda.md`; update roadmap dan README dengan perintah dummy serta batasnya. Update golden hanya untuk perubahan yang disengaja dan periksa gambarnya.

**Interfaces:** Consume seluruh deliverable Task 1 hingga 4; tidak menambah adapter Firebase nyata atau config partner.

- [ ] Jalankan `rtk dart format --output=none --set-exit-if-changed lib test tool integration_test`, `rtk flutter analyze`, focused notification/safety tests, `rtk flutter test`, dan `rtk flutter build apk --debug`. Record hasil aktual, bukan asumsi CI remote.
- [ ] Review akhir keamanan satu kali dengan reviewer independen sesuai skill requesting-code-review; tangani critical/important lewat failing regression test dan satu fix pass. Record setiap temuan accepted/deferred beserta alasannya.
- [ ] Verifikasi manual simulator pada emulator jika tersedia: `rtk flutter run --dart-define=DEMO_MODE=true` dan production repository debug `rtk flutter run --dart-define-from-file=.env --dart-define=PUSH_MODE=dummy`. Tidak melakukan POST token contoh ke server.
- [ ] Tulis report lokal dengan PASS hanya untuk bukti yang dijalankan. Checklist live tetap unchecked: key/config partner, app ID, Firebase/APNs bootstrap nyata, HTTPS, payload notificationId server, delivery Android/iOS, offline logout privacy, token rotation/reinstall OS, dan account switch.
- [ ] Commit exact docs/tests/fix files: `test(notifications): verify dummy push and document live release gates`.

## Self-Review dan Handoff

Coverage spec: registration/pagination Task 1; dummy/config Task 2; session/rotation/logout Task 3; tap/status/simulator Task 4; quality/report/live gate Task 5. Signature dan mode konsisten antartask. Firebase initialization serta delivery sengaja dikecualikan berdasarkan revisi pengguna, bukan ditandai selesai.

Rencana menunggu review pengguna. Metode pelaksanaan: native/inline dalam sesi ini, satu task per urutan, kemudian satu final review independen. Implementasi belum dimulai.
