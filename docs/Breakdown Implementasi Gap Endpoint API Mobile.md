# Breakdown Implementasi Gap Endpoint API HRIS Mobile

Tanggal: 18 September 2026  
Status: Tahap 4 selesai lokal, partial live test, dan real device masih pending  
Target pengujian: Android real device, akun employee dan manager

## 1. Temuan sebelum implementasi

Dua dokumen yang dijadikan sumber saat ini memiliki isi yang sama:

- `docs/Audit Gap Endpoint API Mobile - 2026-09-16.md`;
- `/home/ictsindy/Documents/Audit Gap Endpoint API.md`.

Perbedaan hasil `diff` hanya satu baris kosong pada akhir file. Dokumen kedua belum memuat jawaban backend, fixture response, OpenAPI, base URL HTTPS, matriks permission, atau keputusan untuk pertanyaan yang tercantum pada bagian P0 dan P1 audit.

Karena itu, endpoint yang masih berupa kandidat tidak boleh langsung dihubungkan dengan DTO atau payload hasil asumsi. Implementasi dibagi menjadi lima tahap. Setiap tahap harus menghasilkan build yang dapat diuji tersendiri pada perangkat nyata dan laporan hasil uji sebelum tahap berikutnya dimulai.

## 2. Prinsip urutan kerja

Urutan tahap ditentukan oleh empat hal:

1. session, tenant, dan attendance harus tervalidasi sebelum fitur baru memakai identitas pengguna;
2. Approval Center menjadi dependency action manager untuk koreksi, lembur, cuti, dan izin;
3. endpoint keamanan akun dikerjakan sebelum modul finansial;
4. payroll, push, chat, dokumen, dan recovery tidak diimplementasikan sampai kontrak server tersedia.

Setiap mutation harus memakai hasil server sebagai sumber status. Response HTTP 2xx tanpa data wajib, ID, atau token yang dibutuhkan harus diperlakukan sebagai error kontrak, bukan sukses.

## 3. Tahap 1, finalisasi kontrak dan smoke test jalur yang sudah ada

Prioritas: P0  
Tujuan: membuktikan 24 operasi yang sudah terintegrasi bekerja pada deployment yang akan dipakai aplikasi.

Progress 18 September 2026:

- contract validation dan regression test lokal selesai;
- 24 operasi mempunyai coverage method/path dan response minimum;
- static analysis, 290 test, dan build APK debug lulus;
- akun uji employee/manager tersedia melalui file lokal yang diabaikan Git;
- setelah persetujuan eksplisit, seluruh 24 method/path telah dipanggil pada deployment HTTP: 13 PASS, 7 negative probe tervalidasi, 2 route menunggu fixture, dan 2 FAIL karena kalender kerja/shift akun employee belum dikonfigurasi;
- login mobile employee/manager, refresh rotation, `/auth/me`, logout, dan profile PASS. Response login menyediakan access token dan refresh token;
- positive mutation attendance, leave, permission, change-password, serta read notification by ID masih memerlukan fixture dan pengujian real device;
- hasil lengkap tersedia pada `docs/Report Tahap 1 Finalisasi Kontrak dan Smoke Test API.md`.

### Pekerjaan

| ID | Task | Hasil |
|---|---|---|
| API-001 | Masukkan OpenAPI atau fixture tersanitasi untuk auth, attendance, leave, permission, calendar, notification, dan employee profile. | Contract test memakai bentuk response resmi, termasuk response kosong dan error. |
| API-002 | Konfirmasi URL HTTPS staging, permission employee/manager, pagination, timezone, dan semantics `Idempotency-Key`. | Konfigurasi staging dan matriks capability terdokumentasi. |
| API-003 | Sesuaikan DTO/parser yang berbeda dari fixture resmi tanpa fallback ke data contoh. | Mapping gagal secara eksplisit bila field wajib hilang. |
| API-004 | Jalankan smoke test session, tenant isolation, attendance, leave/permission, calendar, notification, dan profile. | Report hasil per endpoint dan bukti status server. |
| API-005 | Tambahkan regression test untuk setiap mismatch yang ditemukan saat smoke test. | Bug deployment yang sudah ditemukan tidak terulang diam-diam. |

### Gate pengujian manual real device

- login employee, restore setelah aplikasi dimatikan, refresh token, logout, lalu login akun lain;
- login manager dan MFA challenge bila akun mengaktifkannya;
- check-in dan check-out sesuai policy server, termasuk GPS/selfie bila diwajibkan;
- riwayat attendance bulan kosong dan berisi data;
- buat dan batalkan cuti serta izin;
- kalender bulan berjalan, notifikasi read/read-all, dan profil employee;
- matikan koneksi pada loading dan mutation untuk memastikan tidak ada sukses palsu;
- pastikan data akun pertama tidak terlihat setelah pergantian akun.

### Exit gate

- tidak ada response 2xx yang diterima tanpa validasi field wajib;
- tidak ada request yang mengirim employee/company target dari input bebas pengguna;
- tidak ada data lintas akun setelah logout;
- seluruh contract test dan test suite Flutter lulus;
- tersedia akun uji employee dan manager melalui secret lokal atau secret manager.

## 4. Tahap 2, Approval Center manager

Prioritas: P1  
Dependency: Tahap 1 lulus serta fixture Approval Center tersedia.

Progress 18 September 2026:

- live probe non-destruktif telah mencapai enam route Approval Center;
- akun employee ditolak 403 sesuai capability guard;
- akun manager uji juga ditolak 403 pada queue, single action, dan bulk action karena belum memiliki permission `workflow:approve`;
- delegation list PASS, self-delegation ditolak 400, dan revoke ID sentinel ditolak 409 tanpa mengubah data nyata;
- entity, datasource, repository, provider queue/delegation, tenant validation, action validation, dan partial-failure parser telah diimplementasikan;
- 8 contract test Approval Center lulus dan `flutter analyze` proyek tidak menemukan issue;
- route dan capability guard telah aktif. Employee diarahkan kembali ke Beranda, sedangkan manager dengan `workflow:approve` melihat shortcut Approval dan dapat membuka Approval Center;
- layar antrean, detail, approve, reject wajib alasan, escalate, pagination, refresh, bulk selection, partial failure, daftar delegasi, create, dan revoke telah diimplementasikan tanpa data contoh;
- UI menangani loading, empty, error, permission, server conflict, serta layout 320dp pada text scale 200% dalam tema terang dan gelap;
- 8 contract test, 7 widget test Approval Center, 1 regression test router, dan 4 golden test baru lulus. Seluruh 310 test proyek, `flutter analyze`, build APK debug, contrast check, serta `git diff --check` lulus;
- hasil lengkap tersedia pada `docs/Report Tahap 2 Approval Center Manager.md`;
- live positive test tetap menunggu permission `workflow:approve` pada akun manager serta fixture approval/delegasi.

### Endpoint

- `GET /workflow-engine/instances/my-approvals`;
- `POST /workflow-engine/instances/:id/actions`;
- `POST /workflow-engine/instances/bulk-approve`;
- `GET /workflow-engine/delegations`;
- `POST /workflow-engine/delegations`;
- `PATCH /workflow-engine/delegations/:id/revoke`.

### Pekerjaan

| ID | Task | Hasil |
|---|---|---|
| API-101 | Buat entity, DTO, datasource, repository, dan provider antrean approval. | DONE lokal. List mendukung empty, loading, error, pagination, dan refresh. |
| API-102 | Tambahkan route serta layar Approval Center yang hanya tampil untuk capability approver. | DONE lokal. Employee tanpa hak tidak melihat tombol atau route aktif. |
| API-103 | Implementasikan detail, approve, reject, escalate, dan comment sesuai enum server. | DONE lokal. State berubah hanya setelah response server valid. |
| API-104 | Tangani stale action, double action, 403, 404, dan 409 dengan pesan yang dapat ditindaklanjuti. | DONE lokal. Item direfresh dan tidak ditandai sukses secara lokal. |
| API-105 | Implementasikan bulk approve dengan hasil per item dan partial failure. | DONE lokal. Item gagal tetap dipilih beserta alasan server. |
| API-106 | Implementasikan daftar, pembuatan, dan pencabutan delegasi. | DONE lokal. Periode dan status delegasi mengikuti server. |

### Gate pengujian manual real device

- employee tidak mendapat akses Approval Center;
- manager melihat antrean yang sesuai akunnya;
- approve dan reject satu item;
- ulangi action pada item yang sudah selesai untuk memeriksa stale conflict;
- bulk approve campuran sukses dan gagal;
- buat lalu cabut delegasi;
- logout manager lalu login employee dan pastikan cache approval bersih.

## 5. Tahap 3, koreksi absensi dan lembur

Prioritas: P1  
Dependency: Tahap 1 lulus. Action manager memakai fondasi Tahap 2.

### Endpoint koreksi

- `POST /attendance-corrections`;
- `GET /attendance-corrections`;
- `GET /attendance-corrections/:id`;
- `PUT /attendance-corrections/:id/approve`;
- `PUT /attendance-corrections/:id/reject`;
- `PATCH /attendance-corrections/:id/workflow-action`.

### Endpoint lembur

- `GET /attendance/overtime`;
- `POST /attendance/overtime`;
- `GET /attendance/overtime/:id/pay`;
- `PATCH /attendance/overtime/:id/approve`;
- `PATCH /attendance/overtime/:id/reject`;
- `PATCH /attendance/overtime/:id/workflow-action`.

### Pekerjaan

| ID | Task | Hasil |
|---|---|---|
| API-201 | Implementasikan form koreksi dari record attendance dan riwayat status milik employee. | DONE lokal. Form dapat dibuka dari record attendance, mutation memakai idempotency key, dan record final tidak diubah sebelum response server. |
| API-202 | Implementasikan detail/timeline koreksi dan action manager. | DONE lokal. Employee memakai route self-service `/my` dan `/my/:id`; action manager memakai Approval Center generik Tahap 2. |
| API-203 | Implementasikan daftar, form, dan detail lembur. | DONE lokal. Waktu lintas hari divalidasi dan identity employee/company berasal dari session. Positive live create masih BLOCKED permission `attendance:create`. |
| API-204 | Tampilkan estimasi bayaran hanya dari `/pay`, tanpa perhitungan nominal lokal. | DONE lokal. Nominal hanya ditampilkan dari response `/pay`; live positive test menunggu fixture lembur. |
| API-205 | Implementasikan approval lembur melalui action utama yang diputuskan backend. | DONE lokal. Mobile hanya memakai workflow action generik sehingga tidak ada dua jalur mutation manager. Positive live test menunggu permission dan fixture manager. |

Status 19 September 2026: PASS lokal, PARTIAL live, PENDING real device. Detail bukti berada di [Report Tahap 3, Koreksi Absensi dan Lembur](<Report Tahap 3 Koreksi Absensi dan Lembur.md>).

### Gate pengujian manual real device

- koreksi check-in, check-out, keduanya, dan input waktu tidak valid;
- submit koreksi pada record yang bukan milik akun dan pastikan server menolak;
- submit lembur normal dan lintas tengah malam;
- cek konflik shift, duplicate submit, serta estimasi pay gagal;
- manager approve/reject, lalu employee melihat status terbaru;
- pergantian akun tidak membawa draft atau riwayat akun sebelumnya.

## 6. Tahap 4, keamanan akun dan endpoint pendukung

Prioritas: P1 keamanan dan P2 utilitas  
Dependency: Tahap 1 lulus serta schema auth/session tersedia.

Progress 19 September 2026:

- layar Keamanan Akun, contract parser, provider session-aware, setup/enable/disable MFA, daftar sesi, dan revoke sesi selesai lokal;
- secret QR MFA dan recovery code hanya hidup pada alur presentasi, tidak dimasukkan provider, storage, atau log jaringan;
- notifikasi dapat dihapus dengan konfirmasi, optimistic removal, rollback saat server gagal, dan refresh badge;
- 17 test baru/diubah untuk Tahap 4 lulus; seluruh 350 test proyek, static analysis, golden light/dark, build APK debug, contrast check, serta `git diff --check` lulus;
- safe live probe menghasilkan 6 PASS, 2 expected validation rejection, dan 2 route sentinel terjangkau tanpa mengubah MFA, sesi, atau notifikasi nyata;
- positive MFA, revoke sesi nyata, dan delete notifikasi nyata menunggu pengujian manual akun khusus;
- integrasi holiday list ditahan. Resolved calendar sudah menjadi sumber tunggal tanpa duplikasi, sedangkan implementation backend holiday masih menerima `companyId` dari query dan belum mengambil tenant langsung dari session;
- server belum mengirim status MFA maupun penanda current session. Karena itu aplikasi tidak menebak status/current device dan hanya logout lokal jika response sesi kelak secara eksplisit mengirim `current: true` atau `isCurrent: true`;
- hasil lengkap tersedia pada `docs/Report Tahap 4 Keamanan Akun dan Endpoint Pendukung.md`.

### Endpoint

- `POST /auth/mfa/setup`;
- `POST /auth/mfa/enable`;
- `POST /auth/mfa/disable`;
- `GET /auth/sessions`;
- `DELETE /auth/sessions/:id`;
- `GET /work-calendars/holidays/list`;
- `DELETE /notifications/:id`.

### Pekerjaan

| ID | Task | Hasil |
|---|---|---|
| API-301 | Implementasikan setup, enable, dan disable TOTP dengan perlindungan secret. | DONE lokal, PARTIAL live. Secret tidak masuk log/storage; positive flow menunggu manual test. |
| API-302 | Implementasikan daftar sesi aktif dan revoke sesi. | DONE lokal untuk list/revoke. Logout current session BLOCKED sampai backend memberi penanda current/session ID. |
| API-303 | Integrasikan holiday list bila response resolved calendar belum mencukupi kebutuhan UI. | NOT WIRED secara sengaja. Resolved calendar sudah lengkap; tenant contract holiday perlu diperbaiki backend agar tidak berasal dari query pengguna. |
| API-304 | Tambahkan hapus notifikasi dengan konfirmasi dan rollback visual saat server gagal. | DONE lokal, route live terjangkau dengan sentinel 404. Badge dan list direfresh setelah sukses/gagal. |

### Gate pengujian manual real device

- setup MFA, kode salah, enable, login memakai TOTP, lalu disable;
- revoke perangkat lain dan current device;
- hapus notifikasi, gagal jaringan, refresh, dan pindah akun;
- bandingkan hari libur dengan resolved calendar pada batas bulan.

## 7. Tahap 5, ESS lanjutan

Prioritas: P2  
Dependency: kontrak dan fixture setiap submodul tersedia. Submodul diuji satu per satu, tidak dirilis sebagai satu paket besar.

Progress 20 September 2026:

- loan, EWA, daily activity, travel, dan expense claim telah diintegrasikan dalam route `/ess` dengan permission gate, state loading/empty/error, validasi identity tenant, dan cache session-aware;
- live probe non-destruktif menghasilkan 12 PASS dan 5 expected rejection tanpa membuat data;
- akun live belum memiliki `ewa:create` dan `daily-activity:create`, sedangkan loan type serta seluruh riwayat masih kosong;
- workflow loan dan travel memakai Approval Center generik. Workflow EWA tetap BLOCKED karena backend belum menghubungkannya ke workflow engine;
- 8 contract test, 11 widget/session test, dan 8 golden test ESS lulus. Seluruh 377 test proyek, static analysis, build APK debug, contrast check, dan `git diff --check` lulus;
- positive mutation live dan pengujian real device masih PENDING fixture/permission;
- hasil lengkap tersedia pada `docs/Report Tahap 5 ESS Lanjutan.md`.

Urutan implementasi:

1. employee loan: tipe, daftar sendiri, pengajuan, installment, amortization, cancel, **DONE lokal**;
2. EWA: limit, daftar sendiri, pengajuan, detail, cancel, **DONE lokal, create live BLOCKED permission**;
3. daily activity: list, create, detail, update, delete, **DONE lokal, create live BLOCKED permission**;
4. travel dan expense claim: trip, claim, category, attachment, detail, action, **DONE lokal untuk employee list/create/image attachment; detail/action manager melalui Approval Center**;
5. action manager untuk loan, EWA, dan travel melalui mekanisme workflow yang sudah stabil, **DONE loan/travel, BLOCKED EWA workflow backend**.

Setiap submodul harus mempunyai route, permission gate, empty/loading/error state, contract test, logout isolation test, dan satu checklist real-device khusus sebelum submodul berikutnya dimulai.

## 8. Tetap diblokir sampai kontrak backend tersedia

Bagian berikut tidak boleh dibuat memakai endpoint atau data pengganti:

| Capability | Kontrak minimum yang belum tersedia |
|---|---|
| Payroll | PIN/challenge, unlock server, expiry, lockout, protected detail, dan PDF berizin. |
| Push notification | register, rotate, unregister device token, payload, dan konfigurasi environment. |
| Chat | conversation, message, unread, send, attachment, read receipt, dan realtime transport. |
| Dokumen employee | list metadata, preview/download berizin, expiry, dan scope employee. |
| Supervisor/team | reporting line, team today, authorization, dan timezone kantor. |
| Password recovery | forgot/reset flow, token/OTP expiry, rate limit, dan session invalidation. |
| Offline mutation | semantics idempotency, retensi key, konflik, dan aturan timestamp capture. |

## 9. Data backend yang diperlukan untuk memulai Tahap 1

Backend perlu mengirim artefak yang berbeda dari file audit mobile:

- OpenAPI terbaru atau fixture JSON sukses, kosong, 400, 401, 403, 404, dan 409;
- base URL HTTPS staging;
- akun uji employee dan manager melalui lokasi secret lokal yang diabaikan Git (sudah tersedia);
- matriks permission employee/manager;
- enum dan schema Approval Center, correction, overtime, session, serta MFA;
- aturan pagination, timezone, tenant scope, dan `Idempotency-Key`;
- keputusan action utama domain dibanding workflow action.

Setelah artefak tersebut tersedia, pengerjaan dimulai dari API-001 sampai API-005. Report Tahap 1 menjadi titik persetujuan sebelum Tahap 2.
