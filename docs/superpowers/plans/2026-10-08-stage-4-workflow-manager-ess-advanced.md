# Tahap 4 Workflow Manager dan ESS Lanjutan

**Tujuan:** Menutup gap kontrak dan presentasi workflow manager serta ESS lanjutan tanpa membuat data production palsu atau mengklaim live acceptance sebelum fixture backend tersedia.

## Batasan global

- Presentation demo dan production tetap sama; hanya repository/data source yang dapat ditukar.
- Permission memakai `RequestContext.hasPermission`, termasuk wildcard, alias legacy, dan `SUPER_ADMIN`.
- Status mutation baru berubah setelah response server tervalidasi.
- File privat tidak boleh dibuka melalui `/uploads/*`; tanpa endpoint download terotorisasi, aplikasi hanya menampilkan metadata.
- Chat tetap unavailable sampai ada kontrak API.
- Perubahan UI mengikuti handoff yang disetujui: ENERGY 1 / RHYTHM 2 / MOTION 1.

## Task 1, finalisasi Workflow Manager

- Tambahkan `meta.hasNextPage` pada antrean approval.
- Integrasikan `GET /workflow-engine/instances/{id}` untuk detail terbaru.
- Terapkan permission matcher bersama dan larangan self-approval berdasarkan subject identity yang dikirim server.
- Pertahankan reject wajib alasan, bulk partial-success, dan delegasi.
- Tambahkan contract, repository, dan widget tests untuk happy/failure/permission state.

## Task 2, keras-kan kontrak ESS yang sudah ada

- Ganti pemeriksaan permission exact menjadi matcher bersama pada loan, EWA, dan daily activity.
- Terapkan guard permission sebelum request protected dikirim.
- Pertahankan upload receipt resmi dan validasi response server.
- Tambahkan regression tests untuk wildcard permission dan request yang tidak boleh terkirim.

## Task 3, asset, reporting line, dan attachment privat

- Tambahkan model/repository untuk `GET /assets/my`, `GET /employees/me/reporting-line`, dan `GET /employees/{id}/attachments`.
- Validasi pagination, tenant/employee identity, dan schema response.
- Tampilkan asset pada ESS dan reporting line/metadata dokumen pada Profil dengan loading, empty, permission, dan error state jujur.
- Jangan sediakan tombol download bila kontrak endpoint download terotorisasi belum ada.

## Task 4, regresi dan report

- Jalankan focused tests, full test, analyzer, formatter, dan `git diff --check`.
- Perbarui roadmap hanya untuk hasil yang terbukti lokal.
- Buat report Tahap 4 dan pisahkan blocker fixture/live/backend.

## Review focus

- `totalPages = 0` tidak mematikan pagination bila `hasNextPage = true`.
- Detail/action tidak dapat mengakses tenant lain dan self-approval berhenti sebelum mutation.
- Wildcard permission berperilaku sama dengan exact permission.
- Metadata attachment tidak berubah menjadi URL publik atau tombol mati.
- Pergantian akun/company tidak menampilkan late response.

