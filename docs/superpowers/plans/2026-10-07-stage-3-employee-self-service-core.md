# Stage 3 Employee Self-Service Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menyelaraskan riwayat absensi, koreksi/lembur, cuti/izin, kalender kerja, dan perlindungan PII dengan kontrak API mobile terbaru tanpa mengubah presentation demo/production yang sudah disepakati.

**Architecture:** Presentation dan controller tetap dipakai bersama oleh mode demo dan production. Perubahan kontrak ditempatkan pada entity, repository, dan data source; identitas selalu berasal dari `RequestContext`, sedangkan server tetap menjadi sumber kebenaran untuk status, kalender, dan eligibility. Area yang kontraknya belum tegas diberi state tidak tersedia yang jujur dan dicatat sebagai blocker, bukan ditebak.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, `flutter_test`, OpenAPI YAML.

**Spec:** `docs/Breakdown Task Go Live HRIS Mobile App.md`, `docs/api-for-mobile-apps/README.md`, `docs/api-for-mobile-apps/openapi.yaml`, dan `docs/api-for-mobile-apps/checklist-perubahan-api.md`.

## Global Constraints

- Prefix seluruh command repository dengan `rtk`.
- Demo dan production harus memakai presentation/controller yang sama.
- Mutation tidak boleh menampilkan sukses sebelum server mengonfirmasi.
- `employeeId` dan `companyId` hanya dikirim saat kontrak endpoint memang mewajibkannya; nilainya harus berasal dari sesi aktif.
- Lampiran production harus diunggah sebagai multipart dan body create hanya menerima URL terotorisasi hasil server.
- Jangan mengubah visual design kecuali state kosong/error perlu dibuat jujur.
- Jangan menandai positive live PASS tanpa fixture dan bukti dari server.

## Review Focus

- Empty pagination dengan `totalPages: 0` dan `hasNextPage: false` tidak menampilkan halaman `1/0` atau mengaktifkan tombol berikutnya.
- Respons milik employee/company lain harus ditolak sebelum tampil atau masuk cache.
- Retry mutation harus mempertahankan idempotency key tetapi membuat key baru untuk percobaan form baru.
- Collective leave berstatus `APPROVED` harus tampil sebagai riwayat walau tidak pernah dibuat dari aplikasi.
- Nilai PII yang berisi `*` tidak boleh divalidasi sebagai angka atau digunakan sebagai nilai mutation.

---

### Task 1: Pagination Riwayat Absensi Berbasis Metadata Server

**Files:**
- Modify: `lib/features/attendance/domain/entities/attendance_history.dart`
- Modify: `lib/features/attendance/data/datasources/attendance_remote_datasource.dart`
- Modify: `lib/features/attendance/presentation/screens/attendance_screen.dart`
- Modify: `lib/features/attendance/presentation/widgets/attendance_overview.dart`
- Modify: `lib/demo/demo_repositories.dart`
- Test: `test/features/attendance/attendance_api_contract_test.dart`
- Test: `test/features/attendance/attendance_screen_test.dart`

**Interfaces:**
- Consumes: `GET /attendance/me` envelope dengan `meta.page`, `totalPages`, `total`, dan `hasNextPage`.
- Produces: `AttendanceHistoryPage(..., required bool hasNextPage)` yang tidak menghitung ulang eligibility halaman berikutnya.

- [x] **Step 1: Tulis failing contract dan widget tests** untuk `totalPages: 0`, `hasNextPage: false`, serta kasus metadata yang menyatakan `hasNextPage` berbeda dari hasil perhitungan lokal.
- [x] **Step 2: Jalankan test attendance terkait** dengan `rtk flutter test test/features/attendance/attendance_api_contract_test.dart test/features/attendance/attendance_screen_test.dart`; gagal pada parameter baru dan getter turunan lama.
- [x] **Step 3: Implementasikan field metadata eksplisit** pada entity, remote mapper, demo repository, dan UI; hasil kosong mempertahankan `totalPages: 0` dan tombol berikutnya memakai `hasNextPage` server.
- [x] **Step 4: Jalankan kembali kedua test** dan pastikan PASS (24 test).
- [x] **Step 5: Commit** tidak dibuat karena working tree memuat perubahan pengguna; keputusan dicatat di ledger.

### Task 2: Kontrak Cuti dan Izin Production

**Files:**
- Modify: `lib/features/self_service/domain/entities/employee_request.dart`
- Modify: `lib/features/self_service/domain/entities/request_command.dart`
- Modify: `lib/features/self_service/domain/repositories/request_repository.dart`
- Modify: `lib/features/self_service/data/datasources/request_remote_datasource.dart`
- Modify: `lib/features/self_service/data/repositories/request_repository_impl.dart`
- Modify: `lib/features/self_service/presentation/screens/request_form_screen.dart`
- Modify: `lib/features/self_service/presentation/screens/requests_screen.dart`
- Test: `test/features/self_service/request_api_contract_test.dart`
- Test: `test/features/self_service/request_repository_test.dart`
- Test: `test/features/self_service/requests_shared_screen_test.dart`

**Interfaces:**
- Consumes: `RequestContext.employeeId`, `activeCompanyId`, `/leave/types`, `/leave`, `/leave/attachments`, `/leave/{id}`, `/leave/{id}/cancel`, `/permission-requests/my`, `/permission-requests`, dan cancel permission.
- Produces: daftar non-paginated sebagai satu page tanpa query `page/limit`; create leave dengan identity sesi, ISO-8601 lengkap, dan URL lampiran; create permission dengan `duration` serta URL lampiran setelah keputusan kontrak yang tercatat.

- [x] **Step 1: Tulis failing tests daftar** yang memastikan `/leave` dan `/permission-requests/my` tidak menerima query pagination dan list kosong menghasilkan `totalPages: 0`; mapping `APPROVED` sudah ada dan dipertahankan.
- [x] **Step 2: Tulis failing tests create leave** untuk `employeeId`/`companyId` dari sesi, tanggal ISO-8601 penuh, multipart field `attachment`, penggunaan `data.url`, foreign ownership, dan idempotency.
- [x] **Step 3: Jalankan contract tests** dengan `rtk flutter test test/features/self_service/request_api_contract_test.dart`; ekspektasi baru gagal pada tipe attachment, payload, dan availability lama.
- [x] **Step 4: Implementasikan kontrak list dan leave** pada entity/repository/data source serta ubah form agar file diunggah sebelum create dan tidak pernah mengirim base64 sebagai `attachment`.
- [x] **Step 5: Pin keputusan izin**: production form menampilkan unavailable karena unit `duration` dan operasi upload belum dikonfirmasi; demo repository tetap menjalankan flow lokal.
- [x] **Step 6: Jalankan seluruh test self-service** dan pastikan PASS (14 test terfokus).
- [x] **Step 7: Commit** tidak dibuat karena working tree memuat perubahan pengguna; keputusan dicatat di ledger.

### Task 3: Koreksi Absensi dan Lembur

**Files:**
- Modify: `lib/features/attendance_requests/data/datasources/attendance_request_remote_datasource.dart`
- Modify: `lib/features/attendance_requests/data/repositories/attendance_request_repository_impl.dart`
- Modify: `lib/features/attendance_requests/presentation/screens/attendance_requests_screen.dart`
- Test: `test/features/attendance_requests/attendance_request_api_contract_test.dart`
- Test: `test/features/attendance_requests/attendance_requests_screen_test.dart`

**Interfaces:**
- Consumes: endpoint employee correction list/detail/create dan overtime list/create/pay dengan `RequestContext` aktif.
- Produces: mapping strict ownership/company, validation rentang waktu, status server, error permission, dan idempotent create tanpa sukses palsu.

- [x] **Step 1: Tambahkan failing tests** untuk hasil kosong, owner/company asing, permission 403, check-out lintas hari yang sah, waktu terbalik, malformed pay breakdown, dan duplicate submit.
- [x] **Step 2: Jalankan dua suite attendance request** dan verifikasi failure yang diharapkan.
- [x] **Step 3: Terapkan perbaikan minimal** pada mapper/repository/UI state tanpa menambah route manager yang termasuk Tahap 4.
- [x] **Step 4: Jalankan kembali suite** dan pastikan PASS.
- [x] **Step 5: Commit** tidak dibuat karena working tree memuat perubahan pengguna; keputusan dicatat di ledger.

### Task 4: Kalender Kerja, Next Shift, dan Shift Swap

**Files:**
- Modify: `lib/features/calendar/domain/entities/calendar_data.dart`
- Modify: `lib/features/calendar/domain/repositories/calendar_repository.dart`
- Modify: `lib/features/calendar/data/datasources/calendar_remote_datasource.dart`
- Modify: `lib/features/calendar/data/repositories/calendar_repository_impl.dart`
- Modify: `lib/features/calendar/presentation/controllers/calendar_controller.dart`
- Modify: `lib/features/calendar/presentation/screens/calendar_screen.dart`
- Test: `test/features/calendar/calendar_api_contract_test.dart`
- Test: `test/features/calendar/calendar_repository_test.dart`
- Test: `test/features/calendar/calendar_screen_test.dart`

**Interfaces:**
- Consumes: resolved month, next shift, holidays, shift-swap mine/candidates/approvals/create/cancel dengan parameter path `requestId`.
- Produces: `JL` sebagai hari libur non-kerja, nullable next shift, serta state shift-swap loading/empty/error yang tidak membuat data contoh.

- [x] **Step 1: Tulis failing tests kalender** untuk `JL`, `NH`, holiday tanpa jam kerja, `shift: null`, next shift lintas bulan, response malformed, dan error jaringan.
- [x] **Step 2: Tulis failing tests shift swap** untuk daftar kosong, candidate kosong, create/cancel dengan ID aman, ownership asing, serta endpoint `/{requestId}/cancel`.
- [x] **Step 3: Jalankan suite calendar** dan pastikan failure berasal dari capability yang belum ada.
- [x] **Step 4: Tambahkan entity/repository/data source minimal** dan presentasikan state di layar kalender tanpa mengubah layout utama.
- [x] **Step 5: Jalankan seluruh test calendar** dan pastikan PASS.
- [x] **Step 6: Commit** tidak dibuat karena working tree memuat perubahan pengguna; keputusan dicatat di ledger.

### Task 5: Perlindungan PII, Regression, dan Report Tahap 3

**Files:**
- Modify: `lib/features/profile/data/datasources/profile_remote_datasource.dart`
- Test: `test/features/profile/profile_api_contract_test.dart`
- Test: `test/features/profile/profile_repository_test.dart`
- Create: `docs/Tahap 3 Employee Self-Service Inti.md`
- Modify: `docs/Breakdown Task Go Live HRIS Mobile App.md`

**Interfaces:**
- Consumes: permissions `employee:read-sensitive`/`employee:*` dan nilai mask backend berbentuk asterisk.
- Produces: profil read-only yang tidak menjadikan PII masked sebagai input, serta report otomatis/live yang membedakan PASS, BLOCKED, dan belum diuji.

- [x] **Step 1: Tulis failing tests PII** untuk keenam field sensitif, permission biasa, permission sensitive, dan respons masked yang tidak boleh masuk model editable/mutation.
- [x] **Step 2: Jalankan test profile** dan verifikasi failure yang relevan.
- [x] **Step 3: Implementasikan filtering read-only minimal** pada mapper; jangan menambah form edit profil atau menerka nilai penuh.
- [x] **Step 4: Jalankan format, analyzer, seluruh unit/widget/contract/golden tests**, lalu `rtk git diff --check`; semua wajib exit code 0.
- [x] **Step 5: Tulis report Tahap 3** berisi hasil command, cakupan endpoint, blocker kontrak izin, dan daftar positive live yang masih memerlukan fixture.
- [x] **Step 6: Perbarui checklist roadmap** hanya untuk item yang memiliki bukti; jangan centang positive live atau exit gate bila akun/fixture belum tersedia.
- [x] **Step 7: Commit** tidak dibuat karena working tree memuat perubahan pengguna; keputusan dicatat di ledger.
