# Tahap 0: Baseline dan Matriks Kontrak API Mobile

Tanggal audit: 5 Oktober 2026  
Status: **SELESAI lokal, menunggu keputusan backend**

## 1. Baseline yang Dibekukan

| Artefak | SHA-256 |
|---|---|
| `docs/api-for-mobile-apps/README.md` | `62d2257fc9686ac37fa9cd39c01cc70027a963db950dc66e398a1602165eeb2d` |
| `docs/api-for-mobile-apps/checklist-perubahan-api.md` | `86cdf7195f07148d7c3ef3a56973f508de1d5035abbbd588c24bbc61a5867842` |
| `docs/api-for-mobile-apps/openapi.yaml` | `2717710a7ec5be613a880533c12b13e0295dcf9174f51894edb0f29531861640` |

Git HEAD saat audit: `0f7a249c74e97b0db83cb188482eb6a23c5bc2d0`.

Working tree sudah berisi perubahan UI/shared-presentation sebelum audit ini. Perubahan tersebut dipertahankan dan tidak disentuh. Artefak baru Tahap 0 dibatasi pada validator OpenAPI, test validator, dan laporan ini.

## 2. Hasil Validasi OpenAPI

Validator: `tool/mobile_openapi_audit.dart`  
Test: `test/contracts/mobile_openapi_audit_test.dart`

| Pemeriksaan | Hasil |
|---|---|
| YAML dapat diparse | PASS |
| Versi OpenAPI | PASS, `3.1.0` |
| Jumlah method/path | 108 |
| Operasi tanpa `responses` | 0 |
| `operationId` duplikat | 0 |
| `$ref` lokal tidak ditemukan | 0 |
| Kontradiksi `ErrorEnvelope.code` | **FOUND** |

`ErrorEnvelope.required` masih memuat `code`, sementara deskripsinya sendiri menyatakan beberapa response tidak membawa `code`. Backend harus menghapus `code` dari daftar `required`; client tetap wajib memperlakukan field ini sebagai nullable.

## 3. Legenda Status

- **IL**: diimplementasikan dan memiliki test lokal. Belum otomatis berarti positive live test lulus terhadap kontrak terbaru.
- **P**: ada implementasi, tetapi kontrak/payload/semantiknya belum sesuai atau belum pasti.
- **NI**: belum diimplementasikan pada production repository/presentation.
- **NR**: tidak diperlukan native mobile.
- **QA**: endpoint introspeksi untuk smoke/QA, bukan fitur layar pengguna.

Ringkasan: **50 IL, 2 P, 53 NI, 1 NR, dan 2 QA** dari 108 operasi.

## 4. Pemetaan Layer Flutter

| Area | Data source/repository | Controller/presentation | Test utama |
|---|---|---|---|
| Auth/session | `auth_remote_datasource.dart`, `auth_repository_impl.dart`, `core/network/auth_refresh.dart` | `auth_controller.dart`, login/splash/change-password | `auth_api_contract_test.dart`, `auth_refresh_test.dart`, `session_lifecycle_test.dart` |
| Account security | `account_security_repository_impl.dart` | `account_security_screen.dart` | `account_security_test.dart` |
| Attendance | `attendance_remote_datasource.dart`, `attendance_repository_impl.dart` | `attendance_controller.dart`, `attendance_screen.dart` | `attendance_api_contract_test.dart`, repository/use-case/presentation tests |
| Correction/overtime | `attendance_request_remote_datasource.dart` | `attendance_requests_screen.dart` | `attendance_request_api_contract_test.dart` |
| Leave/permission | `request_remote_datasource.dart`, `request_repository_impl.dart` | `request_controller.dart`, request list/form | `request_api_contract_test.dart`, shared-screen tests |
| Approval | `approval_remote_datasource.dart`, `approval_repository_impl.dart` | approval center/delegations | `approval_api_contract_test.dart` |
| Dashboard | `dashboard_remote_datasource.dart`, `dashboard_repository_impl.dart` | `dashboard_controller.dart`, home | dashboard contract/repository/presentation tests |
| Notification | `notification_repository_impl.dart` | `notifications_screen.dart` | `notification_test.dart` |
| Profile | `profile_remote_datasource.dart`, `profile_repository_impl.dart` | `profile_controller.dart`, profile | profile contract/repository/presentation tests |
| Calendar | `calendar_remote_datasource.dart`, `calendar_repository_impl.dart` | `calendar_controller.dart`, calendar | calendar contract/repository/presentation tests |
| Loan/EWA/activity/travel | `dio_ess_repository.dart` | `ess_screen.dart`, `ess_forms.dart` | `ess_api_contract_test.dart`, ESS widget/golden tests |
| Payroll, assets, push registration | Belum ada production repository | Belum ada layar/controller lengkap | Belum ada |

## 5. Matriks 108 Operasi

### Authentication

| Operasi | Status | Catatan |
|---|---|---|
| `POST /auth/login` | IL | MFA retry tersedia. |
| `POST /auth/refresh` | IL | Dilakukan oleh refresh coordinator. |
| `POST /auth/logout` | IL | Mendukung refresh token body. |
| `GET /auth/me` | IL | Bootstrap identitas sesi. |
| `GET /auth/sessions` | IL | Keamanan akun. |
| `DELETE /auth/sessions/{id}` | IL | Revoke session. |
| `POST /auth/change-password` | IL | Session cleanup perlu diregresikan di Tahap 1. |
| `POST /auth/forgot-password` | NI | Belum ada flow UI/repository. |
| `POST /auth/reset-password` | NI | Belum ada deep-link reset flow. |
| `POST /auth/mfa/setup` | IL | Setup QR tersedia. |
| `POST /auth/mfa/enable` | IL | Recovery codes tersedia. |
| `POST /auth/mfa/disable` | IL | Validasi kode tersedia. |
| `GET /auth/csrf` | NR | Native bearer client tidak memakai CSRF cookie flow. |

### Attendance dan Overtime

| Operasi | Status | Catatan |
|---|---|---|
| `GET /attendance/me/today` | IL | Menjadi sumber context/today. |
| `GET /attendance/me` | IL | Riwayat berpaginasi. |
| `POST /attendance/me/check-in` | IL | GPS, selfie, dan idempotency key tersedia. |
| `PATCH /attendance/me/check-out` | IL | GPS tersedia; tidak mengirim wajah. |
| `GET /attendance/overtime` | IL | Masih tergantung permission live. |
| `POST /attendance/overtime` | IL | Masih tergantung permission live. |
| `GET /attendance/overtime/{id}/pay` | IL | Belum ada positive fixture live. |
| `PATCH /attendance/overtime/{id}/approve` | NI | Legacy/domain action tidak dipakai. |
| `PATCH /attendance/overtime/{id}/reject` | NI | Legacy/domain action tidak dipakai. |
| `GET /attendance/overtime/{id}/workflow` | NI | Belum dipakai. |
| `PATCH /attendance/overtime/{id}/workflow-action` | NI | Canonical approval memakai workflow engine. |
| `GET /attendance/{id}` | NI | Belum ada detail attendance langsung. |

### Attendance Correction

| Operasi | Status | Catatan |
|---|---|---|
| `GET /attendance-corrections/my` | IL | Daftar employee. |
| `GET /attendance-corrections/my/{id}` | IL | Detail employee. |
| `GET /attendance-corrections` | NI | Queue manager belum memakai route ini. |
| `POST /attendance-corrections` | IL | Idempotency key tersedia. |
| `GET /attendance-corrections/{id}` | NI | Detail manager belum ada. |
| `PUT /attendance-corrections/{id}/approve` | NI | Canonical approval belum dipetakan. |
| `PUT /attendance-corrections/{id}/reject` | NI | Canonical approval belum dipetakan. |
| `PATCH /attendance-corrections/{id}/workflow-action` | NI | Belum dipakai. |

### Leave

| Operasi | Status | Catatan |
|---|---|---|
| `GET /leave/types` | IL | Cache harus tetap company-scoped. |
| `GET /leave` | IL | Daftar employee. |
| `POST /leave` | P | Client belum mengirim `employeeId` dan `companyId` yang masih diwajibkan schema backend. |
| `GET /leave/balances/employee` | IL | Dipakai dashboard. |
| `POST /leave/attachments` | NI | Client masih memasukkan attachment ke create body. |
| `GET /leave/{id}` | IL | Detail leave. |
| `PATCH /leave/{id}/cancel` | IL | Cancel employee. |
| `PATCH /leave/{id}/approve` | NI | Legacy action tidak dipakai. |
| `PATCH /leave/{id}/reject` | NI | Legacy action tidak dipakai. |
| `GET /leave/{id}/workflow` | NI | Belum dipakai. |
| `PATCH /leave/{id}/workflow-action` | NI | Canonical approval memakai workflow engine. |
| `GET /leave/encashment/policy` | NI | Belum ada modul. |
| `GET /leave/encashment` | NI | Belum ada modul. |
| `POST /leave/encashment` | NI | Belum ada modul. |

### Payroll/Payslip

| Operasi | Status | Catatan |
|---|---|---|
| `GET /payroll/payslips` | NI | Seluruh employee PIN flow belum diimplementasikan. |
| `PUT /payroll/payslips/pin` | NI | Sama. |
| `GET /payroll/payslips/pin/status` | NI | Sama. |
| `POST /payroll/payslips/my/unlock` | NI | Sama. |
| `GET /payroll/payslips/my/{id}` | NI | Sama. |
| `GET /payroll/payslips/my/{id}/pdf` | NI | Sama. |
| `POST /payroll/payslips/unlock` | NI | Admin path bukan employee flow. |
| `POST /payroll/payslips/lock` | NI | Admin path bukan employee flow. |
| `GET /payroll/payslips/{id}` | NI | Admin path belum diperlukan layar employee. |
| `GET /payroll/payslips/{id}/pdf` | NI | Admin path belum diperlukan layar employee. |

### Workflow Engine

| Operasi | Status | Catatan |
|---|---|---|
| `GET /workflow-engine/instances/my-approvals` | IL | Live positive test masih memerlukan permission/fixture. |
| `GET /workflow-engine/instances/{id}` | NI | Detail saat ini berasal dari queue item. |
| `POST /workflow-engine/instances/{id}/actions` | IL | Approve/reject, komentar reject diwajibkan client. |
| `POST /workflow-engine/instances/bulk-approve` | IL | Partial success diparse. |
| `GET /workflow-engine/delegations` | IL | Tersedia. |
| `POST /workflow-engine/delegations` | IL | Tersedia. |
| `PATCH /workflow-engine/delegations/{id}/revoke` | IL | Tersedia. |

### Notifications dan Announcements

| Operasi | Status | Catatan |
|---|---|---|
| `POST /notifications/device-tokens` | NI | Firebase/device registration belum dihubungkan. |
| `DELETE /notifications/device-tokens` | NI | Logout belum menghapus registration backend. |
| `GET /notifications` | IL | Inbox tersedia. |
| `GET /notifications/unread-count` | IL | Tersedia. |
| `PUT /notifications/read` | IL | Tersedia. |
| `PUT /notifications/read-all` | IL | Tersedia. |
| `DELETE /notifications/{id}` | IL | Tersedia. |
| `GET /announcements` | NI | Home saat ini salah memetakan tiga notification sebagai announcement. |
| `GET /announcements/unread-count` | NI | Belum ada. |
| `GET /announcements/{id}` | NI | Belum ada. |
| `PUT /announcements/{id}/read` | NI | Belum ada. |

### Employee/Profile

| Operasi | Status | Catatan |
|---|---|---|
| `GET /employees/me/reporting-line` | NI | Belum ada. |
| `GET /employees/{id}` | IL | Dipakai profil dan branch lookup, bergantung `employee:read`. |
| `GET /employees/{id}/attachments` | NI | Belum ada dokumen profil privat. |
| `GET /employees/{id}/families` | NI | Belum ada. |
| `GET /employees/{id}/emergency-contacts` | NI | Belum ada. |

### Work Calendar dan Shift Swap

| Operasi | Status | Catatan |
|---|---|---|
| `GET /work-calendars/me/resolved` | IL | Calendar utama. |
| `GET /work-calendars/me/next-shift` | NI | Belum ada. |
| `GET /work-calendars/holidays/list` | NI | Belum ada fallback/daftar. |
| `GET /work-calendars/shift-swaps/my` | NI | Belum ada modul. |
| `GET /work-calendars/shift-swaps/candidates/my` | NI | Belum ada modul. |
| `GET /work-calendars/shift-swaps/approvals/my` | NI | Belum ada modul. |
| `POST /work-calendars/shift-swaps` | NI | Belum ada modul. |
| `PATCH /work-calendars/shift-swaps/{requestId}/cancel` | NI | Belum ada modul. |
| `PATCH /work-calendars/shift-swaps/{requestId}/approve` | NI | Belum ada modul. |
| `PATCH /work-calendars/shift-swaps/{requestId}/reject` | NI | Belum ada modul. |

### Assets dan Permission Requests

| Operasi | Status | Catatan |
|---|---|---|
| `GET /assets/my` | NI | Belum ada modul. |
| `GET /assets/{id}` | NI | Belum ada modul. |
| `GET /permission-requests/my` | IL | Daftar employee. |
| `POST /permission-requests` | P | Implemented, tetapi format tanggal/durasi masih belum definitif di dokumen. |
| `PATCH /permission-requests/{id}/cancel` | IL | Tersedia. |

### Loan, EWA, dan Daily Activity

| Operasi | Status | Catatan |
|---|---|---|
| `GET /employee-loans/types` | IL | Tersedia. |
| `GET /employee-loans/my` | IL | Tersedia. |
| `POST /employee-loans` | IL | Tersedia. |
| `PATCH /employee-loans/{id}/cancel` | IL | Tersedia. |
| `GET /ewa/my` | IL | Tersedia. |
| `GET /ewa/my/limit` | IL | Tersedia. |
| `POST /ewa` | IL | Tersedia. |
| `POST /ewa/{id}/cancel` | IL | Tersedia. |
| `GET /daily-activities/my` | IL | Tersedia. |
| `POST /daily-activities` | IL | Branch context masih menjadi blocker live. |
| `POST /daily-activities/{id}/complete` | NI | Client memakai update/delete route lama, bukan complete. |

### Metadata

| Operasi | Status | Catatan |
|---|---|---|
| `GET /meta/endpoints` | QA | Dipakai untuk staging contract comparison, membutuhkan `rbac:read`. |
| `GET /meta/openapi.json` | QA | Dipakai untuk staging schema comparison. |

## 6. Route Client di Luar OpenAPI Mobile

Route berikut masih dipanggil `DioEssRepository`, tetapi tidak ada dalam `openapi.yaml` yang dibekukan:

1. `GET /employee-loans/{id}/installments`
2. `GET /employee-loans/{id}/amortization`
3. `GET /ewa/{id}`
4. `GET /daily-activities/{id}`
5. `PUT /daily-activities/{id}`
6. `DELETE /daily-activities/{id}`
7. `GET /travel-expenses/categories`
8. `GET /travel-expenses/trips/my`
9. `GET /travel-expenses/claims/my`
10. `POST /travel-expenses/trips`
11. `POST /travel-expenses/claims/receipt-upload`
12. `POST /travel-expenses/claims`

Backend harus memilih salah satu: memasukkan route tersebut ke kontrak mobile dengan schema/permission yang jelas, atau menyatakan route tidak didukung agar client menghapus/menonaktifkan flow production. Khusus receipt upload, README menyatakan client harus memakai `data.url`, sedangkan implementasi saat ini membaca `filePath`; ini mismatch yang harus diperbaiki sebelum flow travel dinyatakan aktif.

## 7. Keputusan dan Pertanyaan untuk Backend

| Prioritas | Keputusan yang Dibutuhkan |
|---|---|
| P0 | Hapus `code` dari `ErrorEnvelope.required` atau jamin field selalu dikirim pada seluruh error. Rekomendasi: jadikan opsional agar sesuai runtime. |
| P0 | Konfirmasi payload create leave yang masih mewajibkan `employeeId` dan `companyId`. |
| P0 | Putuskan status 12 route client di luar OpenAPI mobile. |
| P0 | Tetapkan schema response yang cukup ketat untuk identity, pagination, mutation confirmation, dan tenant isolation. |
| P1 | Tetapkan format `shiftDate`. |
| P1 | Tetapkan format `startDate`, `endDate`, dan unit `duration` permission request. |
| P1 | Tetapkan batas ukuran/format upload per endpoint. |
| P1 | Sediakan permission dan fixture positive-live untuk employee serta manager. |
| Release | Sediakan HTTPS staging; OpenAPI saat ini hanya mempunyai placeholder `{baseUrl}`. |

## 8. Exit Gate Tahap 0

- [x] Working tree lama diinventarisasi dan dipertahankan.
- [x] Seluruh 108 method/path memiliki status dan owner area.
- [x] Implementasi Flutter dipetakan sampai data source/repository, presentation, dan test.
- [x] OpenAPI dapat diparse dan diverifikasi otomatis.
- [x] Kontradiksi dokumentasi serta route di luar kontrak dicatat.
- [x] Fingerprint dokumen baseline dicatat.
- [ ] Backend mengonfirmasi keputusan pada bagian 7.

Tahap 1 dapat mulai untuk perubahan client yang tidak bergantung keputusan backend, khususnya nullable error code, classifier 401, refresh single-flight, correlation ID, logging, dan session cleanup. Create leave, permission request, dan route ESS di luar OpenAPI tidak boleh difinalisasi sebelum jawaban backend tersedia.
