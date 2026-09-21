# Report Tahap 2, Approval Center Manager

Tanggal: 18 September 2026  
Scope: antrean approval, action workflow, bulk approve, dan delegasi  
Status tahap: PASS lokal, BLOCKED positive live test, PENDING real device

## 1. Ringkasan hasil

Tahap 2 telah menyelesaikan implementasi kontrak, akses berbasis capability, UI Approval Center, delegation flow, pengujian otomatis, regression test proyek, pemeriksaan aksesibilitas dasar, dan build APK debug.

Hasil utama:

- enam route workflow telah dipetakan ke datasource dan repository tanpa fallback data contoh;
- Approval Center hanya tersedia untuk session dengan permission `workflow:approve`;
- employee tanpa permission tidak melihat shortcut Approval dan akses langsung `/approvals` diarahkan ke Beranda;
- keputusan approve, reject, dan escalate baru dinyatakan berhasil setelah response server tervalidasi;
- reject mewajibkan alasan sebelum request dikirim;
- response 404 atau 409 dianggap stale data, menampilkan pesan, dan memicu refresh antrean;
- bulk approve mempertahankan item gagal dalam kondisi terpilih beserta alasan server;
- delegasi mendukung list, create, dan revoke dengan validasi session, tenant, periode, serta larangan self-delegation;
- loading, empty, error, permission, dan partial-failure state tersedia;
- layout telah diuji pada lebar 320dp, text scale 200%, tema terang, dan tema gelap.

## 2. Endpoint dan status implementasi

| No. | Method | Path | Implementasi lokal | Live 18 September 2026 |
|---:|---|---|---|---|
| 1 | GET | `/workflow-engine/instances/my-approvals` | PASS contract dan UI | Employee 403 sesuai harapan; manager 403 karena belum memiliki `workflow:approve` |
| 2 | POST | `/workflow-engine/instances/:id/actions` | PASS untuk APPROVE, REJECT, ESCALATE, comment, dan stale response | Route terjangkau, tetapi manager 403 sebelum fixture dapat diuji |
| 3 | POST | `/workflow-engine/instances/bulk-approve` | PASS parser hasil per item dan partial failure | Manager 403 karena permission belum tersedia |
| 4 | GET | `/workflow-engine/delegations?mine=true` | PASS list dan scope session | PASS 200, list kosong |
| 5 | POST | `/workflow-engine/delegations` | PASS payload UTC dan validasi | Self-delegation ditolak 400 sesuai kontrak |
| 6 | PATCH | `/workflow-engine/delegations/:id/revoke` | PASS identity serta status inactive | ID sentinel ditolak 409, fixture nyata belum tersedia |

Login dan logout employee/manager yang dipakai untuk probe juga lulus. Artefak tersanitasi berada di `/tmp/hris-mobile-stage2-probe.json` dengan permission `600`. File tersebut tidak menyimpan token, password, cookie, OTP, atau email.

## 3. Perubahan implementasi

### Domain dan data

- entity antrean, page, action enum, bulk result, serta delegasi;
- remote datasource untuk keenam route workflow;
- repository dengan validasi capability, active company, user scope, ID aman, reject reason, duplicate bulk ID, dan konsistensi jumlah hasil bulk;
- queue serta delegation provider yang menolak late response setelah session berubah.

### Navigasi dan akses

- shortcut Beranda berubah dari `Pengajuan` menjadi `Approval` hanya untuk approver;
- quick action Approval Center memakai capability `workflow:approve`;
- route `/approvals` dan `/approvals/delegations` berada di luar bottom navigation agar flow keputusan fokus;
- direct-link kedua route ditolak oleh router bila session tidak memiliki permission.

### UI Approval Center

- refresh, pagination, jumlah antrean, selection, dan bulk action;
- kartu memakai title, requester label bila tersedia, tahap workflow, jenis pengajuan, serta tanggal dari server;
- bottom sheet detail menyediakan approve, reject dengan alasan, dan escalate;
- tombol mutation dinonaktifkan selama request berjalan untuk mencegah double action;
- server tetap menjadi sumber status. UI tidak menghapus atau menandai item sukses sebelum response valid;
- delegation screen menyediakan create, active/inactive state, periode, reason, dan revoke confirmation.

Desain mengikuti token aplikasi yang sudah disepakati: Plus Jakarta Sans, primary `#315B8C`, radius card 22px, padding layar 20px, SafeArea, serta tema terang/gelap.

## 4. Hasil pengujian otomatis

| Gate | Hasil |
|---|---|
| Contract test Approval API | 8 lulus |
| Widget test Approval Center dan delegasi | 7 lulus |
| Regression router capability | 1 lulus |
| Golden test Approval Center dan delegasi | 4 lulus dan telah diinspeksi visual |
| Seluruh test proyek | 310 lulus |
| `flutter analyze` | Lulus, tidak ada issue |
| Contrast check 9 pasangan warna relevan | Seluruhnya lulus WCAG 4.5:1 untuk teks normal |
| Layout 320dp, text scale 200%, light/dark | Lulus tanpa overflow |
| `flutter build apk --debug` | Lulus |
| `git diff --check` | Lulus |

APK pengujian:

- file: `build/app/outputs/flutter-apk/app-debug.apk`;
- ukuran: 204372754 byte;
- SHA-256: `2b14d67dbed7e2f036f4ac9cf6372c5e91f7ea5ca30de3e3ef8bd5b8515714d0`.

Build masih menampilkan warning bahwa `package_info_plus` menerapkan Kotlin Gradle Plugin. Warning ini tidak menggagalkan build, tetapi dependency perlu diperbarui sebelum Flutter menghapus dukungan pola tersebut.

## 5. Hasil live probe

Probe dilakukan secara non-destruktif melalui base URL HTTP yang telah disetujui untuk akun uji.

| Skenario | HTTP | Hasil |
|---|---:|---|
| Login employee | 200 | PASS, Bearer access dan refresh token tersedia |
| Login manager | 200 | PASS, Bearer access dan refresh token tersedia |
| Employee membuka queue | 403 | PASS capability guard, backend meminta `workflow:approve` |
| Manager membuka queue | 403 | BLOCKED, akun manager belum memiliki `workflow:approve` |
| Manager single action sentinel | 403 | Route terjangkau, positive action belum dapat diuji |
| Manager bulk action sentinel | 403 | BLOCKED oleh permission |
| Manager membaca delegasi sendiri | 200 | PASS, list kosong valid |
| Manager self-delegation | 400 | PASS negative validation, tidak membuat data |
| Manager revoke sentinel | 409 | PASS negative validation, tidak mengubah data |
| Logout kedua akun | 200 | PASS |

Tidak ada approval atau delegasi nyata yang dimutasi oleh probe ini.

## 6. Blocker backend untuk positive live test

Backend developer perlu menyiapkan:

1. permission `workflow:approve` pada akun manager uji;
2. minimal satu pending approval milik manager untuk approve dan satu untuk reject;
3. beberapa pending approval untuk skenario bulk sukses dan partial failure;
4. satu user manager lain sebagai target delegation;
5. aturan yang pasti apakah endpoint delegasi juga wajib `workflow:approve`, karena deployment saat ini mengizinkan list delegasi pada akun manager yang tidak mempunyai permission tersebut;
6. base URL HTTPS untuk penggunaan di luar pengujian sementara.

Setelah data tersedia, jalankan positive smoke test dengan ID fixture staging. Jangan memakai approval karyawan production.

## 7. Checklist pengujian manual real device

### Capability dan navigasi

- [ ] Login employee. Shortcut harus tetap `Pengajuan`, bukan `Approval`.
- [ ] Coba deep link `/approvals`. Harapan: kembali ke Beranda.
- [ ] Login manager dengan `workflow:approve`. Shortcut `Approval` harus muncul.
- [ ] Buka Approval Center dan lakukan pull-to-refresh.

### Antrean dan single action

- [ ] Cocokkan jumlah dan item antrean dengan response server.
- [ ] Buka detail satu item dan pilih Setujui.
- [ ] Buka item lain, pilih Tolak tanpa alasan. Harapan: form menolak submit.
- [ ] Isi alasan, submit, lalu pastikan status hanya berubah setelah response server.
- [ ] Uji Eskalasi pada fixture yang memang mendukung action tersebut.
- [ ] Selesaikan item dari client lain lalu ulangi action pada mobile. Harapan: pesan stale 404/409 dan antrean direfresh.
- [ ] Tekan action berulang saat request berjalan. Harapan: hanya satu mutation dikirim.

### Bulk approval

- [ ] Pilih beberapa item dan batalkan pilihan.
- [ ] Pilih kembali lalu bulk approve.
- [ ] Uji fixture campuran sukses dan gagal. Harapan: item gagal tetap terpilih dan alasan server terlihat.
- [ ] Matikan jaringan saat bulk action. Harapan: tidak ada item yang diklaim sukses secara lokal.

### Delegasi dan isolasi session

- [ ] Buka delegasi kosong dan delegasi aktif.
- [ ] Buat delegasi dengan target valid serta periode yang diizinkan backend.
- [ ] Coba delegasi ke diri sendiri. Harapan: ditolak.
- [ ] Cabut delegasi aktif dan pastikan status mengikuti response server.
- [ ] Logout manager, login employee, lalu pastikan antrean serta delegasi manager tidak terlihat.

## 8. Exit gate tahap 2

Implementasi lokal API-101 sampai API-106 selesai dan lulus seluruh gate otomatis. Tahap 2 belum dapat dinyatakan DONE deployment sampai:

- manager test account memiliki `workflow:approve`;
- approve, reject, escalate, stale conflict, bulk partial failure, create delegation, dan revoke delegation lulus terhadap fixture nyata;
- checklist real device selesai tanpa kebocoran data antar akun;
- hasil manual dicatat dengan waktu, role, HTTP status, error code, dan request ID bila tersedia.

Jangan memasukkan access token, refresh token, password, cookie, OTP, atau data pribadi karyawan ke report manual.
