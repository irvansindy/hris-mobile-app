# Breakdown Task HRIS Mobile App

Tanggal baseline: 10 September 2026.

Acuan: [Audit kondisi aktual](<Audit HRIS Mobile App - 2026-09-10.md>) dan [Checklist Perbaikan](<Checklist Perbaikan HRIS Mobile App.md>).

Dokumen ini memecah backlog audit menjadi task yang dapat dikerjakan dan ditutup satu per satu. Implementasi yang sudah ada dilengkapi atau diperbaiki; tidak otomatis dibuat ulang. Status default **TODO**, kecuali pembaruan eksplisit pada task terkait.

## 1. Cara membaca urutan

- **P0:** kehilangan/ketidakakuratan data, keamanan sesi, serta blocker penggunaan dan rilis.
- **P1:** fondasi routing, state, identitas dan navigasi yang diperlukan fitur berikutnya.
- **P2:** kelengkapan fitur ESS dan Approval.
- **P3/P4:** kualitas tampilan, observability, build dan distribusi.
- Nomor task menunjukkan urutan rekomendasi. Dependency menunjukkan prasyarat teknis, bukan keharusan menunggu seluruh task sebelumnya.
- Owner merupakan **peran yang disarankan**, bukan penugasan orang atau izin mengubah backend. Task server/infra perlu dikerjakan pada repository dan lingkungan terkait.
- Endpoint pada checklist merupakan kandidat sampai metode, path dan schema-nya terverifikasi. Jangan menebak endpoint yang belum terdokumentasi.
- Belum ada estimasi hari/sprint: akses backend, jumlah engineer, dan kapasitas QA belum diketahui. Gunakan ukuran perubahan dan kontrak yang sudah jelas saat membuat estimasi.

Pekerjaan visual P3 dimulai setelah blocker P0 ditutup. CI, i18n dasar, dan routing disiapkan lebih awal karena menjadi prasyarat pembuktian fitur, form baru, dan push/deep link.

## 2. Antrean pertama: sesi aman dan tidak ada sukses palsu

### HRIS-001 — P0: pastikan kontrak autentikasi dan identitas ESS

**Status: REVIEW. Kontrak final mobile Bearer diterapkan dan test lokal selesai; verifikasi akun/server live masih tertunda.** Dokumen final backend 12 September 2026 menggantikan hasil audit cookie-native sebelumnya. Bukti aktif: [API Integration Revision](<API_INTEGRATION_REVISION.md>).

**Owner:** Mobile + Backend + QA. **Dependency:** akses source/OpenAPI backend atau respons tersanitasi dan akun uji. **Acuan audit:** DEV-01, F05/F10.

- [x] Verifikasi kontrak source login, `/auth/me`, refresh, logout, kewajiban ganti password, dan error kredensial/lockout; tambahkan test kontrak mobile lokal.
- [x] Dokumentasikan cookie `at`/`rt`/`csrf`, scope/expiry/rotasi dan fallback Bearer dari source. Sesuaikan pembacaan CSRF mobile.
- [ ] Verifikasi header login dan request lanjutan pada deployment nyata menggunakan akun khusus uji.
- [x] Tentukan sumber `employeeId`, company aktif, company scope, roles/permissions, serta perilaku akun non-employee; uji DTO dan request context.
- [ ] Siapkan akun employee A/B, manager, dan admin non-employee; simpan hanya fixture tersanitasi di repository.
- [x] Buat fixture sintetis employee/manager/admin tanpa kredensial asli untuk pengujian lokal.
- [x] Dokumentasikan kontrak transport native dan batas dukungan web; pengujian perangkat masih terpisah.

**Selesai jika:** ada kontrak tertulis dan fixture sukses/error; login HTTP 200 terbukti menghasilkan kredensial yang diterima oleh `/auth/me`. Keberadaan `csrfToken` saja tidak dianggap bukti autentikasi cookie.

### HRIS-002 — P0: isolasi data ketika logout atau berganti akun

**Status: DONE (lokal), 11 September 2026.** Implementasi dan 18 test baru selesai; seluruh 66 test lulus dan analyzer bersih. Bukti, aturan provider/cache, dan batas pengujian: [laporan HRIS-002](<HRIS-002 Isolasi Data Sesi.md>). Verifikasi akun live/perangkat belum dilakukan.

**Owner:** Mobile + QA. **Dependency:** tidak ada untuk reproduksi dan perbaikan lokal. **Acuan:** DEV-02, F03.

- [x] Buat test reproduksi A → buka fitur → logout → login B dalam proses aplikasi yang sama.
- [x] Ikat lifecycle provider fitur ke identitas sesi/company; invalidasi state terkait saat logout, session invalid, atau perubahan company.
- [x] Batalkan atau abaikan hasil request dari sesi lama, termasuk penulisan kredensial hasil refresh terlambat.
- [x] Siapkan mekanisme pembersihan cache per akun: scope provider dan hook disposal; cache memori yang ada dibangun ulang. Integrasi penghapusan cache disk/dokumen mengikuti implementasi fitur tersebut.

**Selesai jika:** B tidak pernah melihat profil, absensi, pengajuan, atau respons tertunda milik A; hasil refresh sesi lama tidak menghidupkan kembali sesi yang sudah logout.

### HRIS-003 — P0: perbaiki restore, refresh dan retry autentikasi

**Status: DONE (lokal), 11 September 2026.** Seluruh 26 skenario khusus refresh lulus; seluruh 103 test lulus dan analyzer bersih. Bukti dan matriks kegagalan: [laporan HRIS-003](<HRIS-003 Restore Refresh dan Retry.md>). Verifikasi akun/server live belum dilakukan.

**Owner:** Mobile + QA. **Dependency:** HRIS-002; fixture Bearer lokal bisa disiapkan sambil HRIS-001 berlangsung. **Acuan:** DEV-02, F04/F06.

- [x] Cegah `restoreSession` menyimpan ulang token lama setelah `/auth/me` memicu refresh.
- [x] Pertahankan satu refresh untuk request 401 yang bersamaan.
- [x] Retry protected request maksimal satu kali; invalidasi sesi jika refresh atau retry tetap ditolak karena autentikasi.
- [x] Kecualikan kegagalan login dari refresh sesi lama; bedakan koneksi gagal dari kredensial invalid.

**Selesai jika:** test `/me` 401 → refresh → `/me` 200 mempertahankan token terbaru; concurrent 401, refresh gagal, retry 401 dan login salah menghasilkan state yang tepat tanpa loop.

### HRIS-004 — P0: finalisasi cookie/CSRF dan pembatasan kredensial

**Status: DONE (lokal), 11 September 2026.** Native contract diuji pada HTTP loopback dan secure-storage mock; web debug build berhasil. Seluruh 103 test lulus dan analyzer bersih. Bukti, aturan transport, serta batas browser/live: [laporan HRIS-004](<HRIS-004 Cookie dan CSRF.md>).

**Owner:** Mobile + Backend + QA. **Dependency:** HRIS-001/003. **Acuan:** DEV-02, F05.

- [x] Sesuaikan transport dengan kontrak auth yang sudah dibuktikan; identifikasi cookie autentikasi secara eksplisit.
- [x] Terapkan scope origin/path, expiry, penghapusan dan rotasi cookie yang benar.
- [x] Cegah header autentikasi dikirim ke host yang tidak diizinkan; uji redirect sesuai adapter yang digunakan.
- [x] Tolak respons refresh yang tidak membuktikan sesi valid; cookie non-auth tidak boleh membuka sesi.
- [x] Implementasikan konfigurasi browser tersendiri jika web tetap ditargetkan.

**Selesai jika:** login → request protected → refresh → restart aplikasi → logout lulus pada platform target, dengan test cookie kedaluwarsa, cookie non-auth, dan URL di luar origin.

### HRIS-005 — P0: hentikan aksi sukses palsu dan tampilan data contoh

**Owner:** Mobile + QA. **Dependency:** tidak ada untuk menghentikan simulasi; integrasi akhir absensi di HRIS-012. **Acuan:** DEV-04, F01/F07.

- [x] Hapus `_clockedInOverride` dan toggle sukses lokal dari Home; arahkan pengguna ke alur absensi yang tersedia tanpa mengklaim pencatatan berhasil.
- [x] Hapus klaim GPS/wajah terverifikasi sebelum pemeriksaan nyata.
- [x] Hentikan submit pengajuan ke list demo sebagai transaksi pengguna nyata.
- [x] Hilangkan nominal gaji, aset, sertifikasi, riwayat dan event contoh dari tampilan pengguna; bedakan fitur belum tersedia dari data kosong hasil API.
- [x] Sembunyikan/nonaktifkan aksi yang belum memiliki alur; pengaktifannya kembali menjadi bagian task fitur terkait.

**Selesai jika:** pengguna tidak bisa melihat status absensi/pengajuan berhasil tanpa transaksi server; tidak ada identitas, nominal atau riwayat contoh yang disajikan sebagai data pribadi. Ini penghentian simulasi, bukan penutupan integrasi modul.

### HRIS-006 — P0: amankan konfigurasi koneksi dan logging

**Status: DONE (lokal), 11 September 2026.** Guard production, logger metadata-only, pembatasan cleartext per build, dan konfigurasi publik telah diuji. Seluruh 122 test lulus, analyzer bersih, serta APK debug/release dan Web release berhasil dibangun. Bukti dan batas verifikasi deployment: [laporan HRIS-006](<HRIS-006 Koneksi dan Logging Aman.md>).

**Owner:** Mobile + Backend/Infra. **Dependency:** URL HTTPS environment untuk verifikasi final. **Acuan:** DEV-03, F08.

- [x] Pisahkan konfigurasi development dan produksi; release menolak fallback HTTP.
- [x] Hapus/redaksi token, cookie, CSRF, identitas dan isi data sensitif dari log request/response.
- [x] Batasi pengecualian cleartext Android/iOS pada environment development yang memang membutuhkan.
- [x] Pastikan asset `.env` hanya memuat konfigurasi publik, bukan kredensial layanan.

**Selesai jika:** koneksi produksi memakai HTTPS, log uji tidak membocorkan data sensitif, dan konfigurasi salah gagal dengan pesan yang dapat ditindaklanjuti.

### HRIS-007 — P0 pendukung: pasang CI dasar

**Status: DONE (lokal), 12 September 2026.** Workflow quality dan Android
release, guard produksi, coverage artifact, serta test struktur workflow telah
ditambahkan. Bukti dan batas runner pertama: [laporan HRIS-007](<HRIS-007 CI Dasar.md>).

**Owner:** Mobile + DevOps. **Dependency:** tidak ada untuk workflow lokal; aktivasi memerlukan repository CI. **Acuan:** DEV-03/13.

- [x] Tambahkan workflow formatter check, analyzer dan test; gunakan versi Flutter yang konsisten.
- [x] Tambahkan build Android dan penyimpanan laporan test/coverage sebagai artefak CI.
- [x] Cegah konfigurasi/demo mode aktif pada release; guard memeriksa jalur produksi, bukan sekadar nama file.

**Selesai jika:** PR dengan format/lint/test gagal atau demo mode release ditolak pemeriksaan CI. Job awal belum dianggap bukti signing distribusi; itu HRIS-046.

### HRIS-008 — P0: selesaikan bootstrap employee/company dan akses sesi

**Status: DONE (lokal), 12 September 2026.** Bootstrap membedakan login,
mandatory password change, akun non-employee, dan sesi ESS. MFA serta kontrak
change-password diuji. Bukti dan batas live test: [laporan HRIS-008–012](<HRIS-008-012 Bootstrap dan Absensi Nyata.md>).

**Owner:** Mobile + Backend + QA. **Dependency:** HRIS-001–004. **Acuan:** DEV-01/02, F06/F10.

- [x] Muat identitas employee/company dari sumber kontrak yang benar; jangan mengisi ID contoh untuk admin non-employee.
- [x] Tampilkan state yang sesuai untuk akun tanpa kapabilitas ESS; notifikasi tidak ikut gagal hanya karena employee tidak ada jika kontraknya tidak mensyaratkan.
- [x] Terapkan gate `mustChangePassword` beserta form dan endpoint terverifikasi.
- [x] Petakan error login/lockout dan recovery akses secara benar. Route forgot/reset belum tersedia di backend sehingga tidak direka di mobile.

**Selesai jika:** employee, manager dan non-employee mendapat kapabilitas yang tepat; akun wajib ganti password tidak masuk fitur biasa sebelum proses selesai; akses server tetap menegakkan scope/permission.

**Gate A:** HRIS-001–008 selesai. Sesi aman dipakai untuk integrasi berikutnya, state akun tidak tercampur, dan simulasi tidak disajikan sebagai keberhasilan.

## 3. Absensi nyata dari perangkat sampai server

| ID / prioritas | Cakupan task | Dependency / owner | Kriteria selesai |
|---|---|---|---|
| HRIS-009 · P0 · DONE lokal / LIVE REVIEW | Kontrak final self-service `/attendance/me/*` diterapkan dan fixture lokal lulus. Identity dan timestamp client sudah dihapus dari payload. Response deployment belum diverifikasi. | HRIS-001; Mobile + Backend | Fixture policy/check-in/check-out; aturan multi-shift, akurasi, waktu dan penolakan terdokumentasi. Gap server menjadi task backend yang eksplisit. |
| HRIS-010 · P0 · DONE lokal | GPS hardcode diganti geolocator; model accuracy/mock/timestamp/altitude/heading, permission platform, error, timeout, dan CTA settings diterapkan. Smoke test perangkat masih wajib. | HRIS-009; Mobile + QA perangkat | Lokasi nyata diperoleh; permission denial/cancel/GPS mati/akurasi buruk/mock menghasilkan state yang benar, tidak meninggalkan loading. |
| HRIS-011 · P0 · MOBILE DONE / LIVE REVIEW | Kamera depan, kompresi, preview/cancel, payload raw selfie data URI, liveness metadata, batas ukuran, dan cleanup selesai. Dokumen final menyatakan pipeline face server tersedia; keberhasilannya belum dibuktikan pada deployment. | HRIS-006/009; Mobile + Backend + QA | Attachment diterima server; batal/gagal upload tidak dianggap verified. Label face recognition tidak aktif tanpa verifikasi nyata. |
| HRIS-012 · P0 · DONE lokal / LIVE REVIEW | Home dan Attendance memakai endpoint self-service yang sama; context/record server, payload GPS/selfie, state, server rejection, server-time request, dan double-submit guard selesai serta diuji. Live account/device test masih tertunda. | HRIS-003/004/005/008/010/011; Mobile | Status kedua layar berasal dari hasil server; error tidak menjadi sukses; transaksi tidak ganda; aturan clock-in ulang sesuai shift. |
| HRIS-013 · P0 · REVIEW backend live | Dokumen final menyatakan geofence, identity, server time, accuracy/mock, liveness/face dan rate limit ditegakkan server. Mobile sudah berhenti mengirim identity/timestamp, tetapi pengujian payload modifikasi, replay, dan server idempotency belum tersedia. | HRIS-009/012; Backend + Mobile + QA | Skenario di luar radius, payload dimodifikasi, identitas berbeda, timestamp palsu dan duplikasi diuji. Pengakuan `isMocked=false` dari client saja tidak diterima sebagai bukti anti-manipulasi. |
| HRIS-014 · P0 | Ambil riwayat/policy dari server; sinkronkan tanggal, nama kantor, status, durasi, tahun, pagination dan timezone WIB/WITA/WIT. | HRIS-009/012; Mobile | Tidak ada riwayat Juni 2025 atau jam tetap; uji pergantian hari/bulan/tahun dan zona waktu kantor. |

**Gate B:** HRIS-009–014 selesai dan smoke test perangkat serta server tersedia. Absensi dapat digunakan untuk uji operasional terbatas; ini belum berarti aplikasi siap rilis penuh.

## 4. Data nyata dan fondasi fitur ESS

| ID / prioritas | Cakupan task | Dependency / owner | Kriteria selesai |
|---|---|---|---|
| HRIS-015 · P1 pendukung P0 | Buat state loading/empty/error/offline/permission yang konsisten dan fondasi i18n `id_ID`; locale tersimpan. | HRIS-008; Mobile | Data nol berbeda dari gagal muat; pesan/tombol retry dapat dipakai ulang; form baru memakai locale terpusat. |
| HRIS-016 · P0 | Perbaiki dashboard/profile remote: scope personal, mapping field, status tiap section, retry; hilangkan fallback statistik rekaan. | HRIS-008/014/015; Mobile + Backend | API gagal tidak ditampilkan sebagai saldo nol/kehadiran 100%; company aggregate tidak keliru dipakai sebagai statistik employee. |
| HRIS-017 · P0 | Verifikasi work calendar/holiday/shift; ganti calendar datasource demo, Upcoming hardcode dan tombol Today. | HRIS-008/015; Mobile + Backend | Kalender bulan/tahun aktual berasal dari server, timezone benar, loading/kosong/error terbedakan. |
| HRIS-018 · P0 | Integrasikan katalog leave type, saldo per tipe dan list/detail pengajuan dengan pagination/filter serta scope employee. | HRIS-008/015; kontrak leave/permission; Mobile + Backend | List dan saldo cocok dengan server, status detail benar, tidak ada R001–R005 hardcode. |
| HRIS-019 · P0 | Form cuti/izin nyata: date range, alasan terikat ke model, hari kerja, lampiran, preview approver bila tersedia, submit dan timeline. | HRIS-017/018; Mobile + Backend | Server memvalidasi kuota/tanggal/permission; submit menghasilkan ID server; data tetap ada setelah restart; cancel/retry tidak menghasilkan duplikasi. |
| HRIS-020 · P0 | Tutup seluruh jalur demo produksi; cache berasal dari hasil server dan terisolasi per akun; putuskan fixture/demo hanya pada development/test. | HRIS-005/014/016/017/019, HRIS-007 untuk guard; Mobile + QA | Build pengguna nyata tidak memakai `Demo*DataSource` sebagai sumber; tidak ada nominal/tanggal/record contoh; tidak ada submit lokal yang menyamar sebagai transaksi. |

**Gate C:** HRIS-015–020 selesai. Profil, dashboard, kalender dan pengajuan dasar memakai data nyata. Modul yang belum selesai tetap tidak mengklaim siap digunakan.

## 5. Routing, role dan notifikasi

| ID / prioritas | Cakupan task | Dependency / owner | Kriteria selesai |
|---|---|---|---|
| HRIS-021 · P1 pendukung P0 | Implementasikan router dan shell state; route detail pengajuan/approval/slip/attendance, auth guard, back Android dan link setelah login. | HRIS-008/015; Mobile | Route dapat dibuka langsung, state tab terjaga, back benar, detail/form tidak membawa bottom bar yang tidak diperlukan. |
| HRIS-022 · P1 | Integrasikan resolved RBAC; navigasi employee/manager; empat tab dan aksi absensi utama; kalender masuk Kehadiran. | HRIS-012/017/021; kontrak RBAC; Mobile + QA | Menu sesuai kapabilitas; non-employee tidak mendapat aksi ESS yang tidak valid; label ID, badge hook, safe inset dan perilaku tab diuji. |
| HRIS-023 · P0/P2 | Notifikasi inbox, detail, unread-count, read dan read-all; pisahkan kebutuhan employee dari notifikasi user. | HRIS-015/021; kontrak notifikasi; Mobile + Backend | Unread count sinkron sesudah dibaca; inbox paginated, retry tersedia; detail mengarah ke resource yang benar. |
| HRIS-024 · P0 | Firebase init; izin notifikasi; registrasi/rotasi/penghapusan FCM token; foreground/background/terminated; routing notifikasi. | HRIS-006/008/021/023; Firebase config, app ID final, endpoint device token; Mobile + Backend + Infra | Token terikat user/perangkat, terlepas saat logout; notifikasi tiga lifecycle membuka detail sesuai izin tanpa bocor ke akun lain. |
| HRIS-025 · P0 | Reminder lupa clock-out lokal berdasarkan shift/timezone/status server; pembatalan saat checkout/logout dan rekonsiliasi setelah restart. | HRIS-012/014/024; Mobile + QA perangkat | Pengingat muncul pada waktu tepat, tidak berulang sesudah checkout dan tidak tersisa setelah logout. |

Routing dasar boleh dikerjakan saat integrasi data berlangsung. Perubahan visual bottom bar pada HRIS-022 dibatasi kebutuhan navigasi dan aksi; pemolesan P3 tetap menunggu P0. App ID final untuk HRIS-024 perlu diputuskan sejak awal, walaupun signing distribusi ditutup di HRIS-046.

## 6. Approval, slip gaji dan dokumen

| ID / prioritas | Cakupan task | Dependency / owner | Kriteria selesai |
|---|---|---|---|
| HRIS-026 · P2 utama | Approval Center: my-approvals, detail, approver chain, pagination/filter, badge pending. | HRIS-019/021/022; kontrak workflow; Mobile + Backend | Manager melihat pekerjaan yang berhak ditangani; employee tidak melihat inbox approval tanpa kapabilitas. |
| HRIS-027 · P2 utama | Approve/reject, alasan, bulk approval, conflict dan partial failure; sinkronkan status pengajuan/notifikasi. | HRIS-023/026; Mobile + Backend + QA | Server menegakkan permission/state transition; double action aman; optimistic update bila dipakai melakukan rollback; kegagalan sebagian bulk terlihat. |
| HRIS-028 · P0 keamanan | Implementasi biometric/PIN unlock, fallback, relock pada background sesuai kebijakan dan penanganan sesi kedaluwarsa. | HRIS-002/004/008/021; keputusan kebijakan unlock; Mobile + QA perangkat | Unlock lokal tidak menggantikan auth server; kredensial tidak bocor; cancel/failure/fallback dan logout diuji. |
| HRIS-029 · P0 keamanan | Fondasi file pribadi: download berizin, encrypted storage jika disimpan, lifecycle temp file, logout cleanup, screenshot protection sesuai kapabilitas platform. | HRIS-002/006/021/028; kontrak file; Mobile + Backend | File akun A tidak dapat dibuka setelah logout/login B; tidak tersimpan plaintext tanpa kebutuhan; proteksi layar dan batas platform diuji/dicatat. |
| HRIS-030 · P2 utama | Slip gaji: daftar periode, detail komponen/THR, PDF, format uang dan akses per employee. | HRIS-021/029; kontrak payroll; Mobile + Backend | Nilai cocok server; PDF periode benar; user lain ditolak server; tidak ada gaji contoh. |
| HRIS-031 · P2 utama | Dokumen pribadi: list/detail/preview/download dan expiry URL bila ada; hidupkan menu Documents. | HRIS-021/029; kontrak dokumen; Mobile + Backend | Dokumen dapat dipreview/diunduh sesuai izin; kedaluwarsa/file gagal dapat dipulihkan tanpa membocorkan file. |

Proteksi sesi/berkas P0 harus selesai sebelum HRIS-030/031 ditutup. Jika backend tidak memiliki endpoint daftar slip/dokumen yang dibutuhkan, buat task backend terlebih dahulu; jangan menyimpulkan endpoint download sudah cukup untuk seluruh fitur.

## 7. Fitur ESS lanjutan dan offline

| ID / prioritas | Cakupan task | Dependency / owner | Kriteria selesai |
|---|---|---|---|
| HRIS-032 · P2 | Koreksi absensi: pilih record, waktu/alasan/lampiran, submit, status approval. | HRIS-014/019/027; kontrak correction; Mobile + Backend | Koreksi tidak langsung mengubah record final tanpa aturan approval; status dan histori server konsisten. |
| HRIS-033 · P2 | Lembur: form/list/detail, waktu lintas hari, estimasi bayaran, approval. | HRIS-017/019/027; kontrak overtime; Mobile + Backend | Durasi dan estimasi berasal dari aturan server, konflik jadwal ditangani, hasil approval sinkron. |
| HRIS-034 · P2 | Tukar shift: kandidat, pengajuan, persetujuan pihak terkait, pembaruan kalender. | HRIS-017/027; kontrak shift swap; Mobile + Backend | Hanya kandidat berizin tersedia; jadwal final berubah sesudah approval; konflik dan penolakan terlihat. |
| HRIS-035 · P2 | Perjalanan dinas dan reimbursement: trip/claim, foto nota, nominal/currency, daftar/detail, approval. | HRIS-019/027/029; kontrak travel/expense; Mobile + Backend | Upload dan nilai tersimpan server; duplicate submit aman; status dan dokumen dapat ditelusuri. |
| HRIS-036 · P2 | Kasbon/pinjaman: eligibility, pengajuan, cicilan dan amortisasi. | HRIS-027/029; kontrak loan; Mobile + Backend | Jadwal cicilan dan sisa pinjaman cocok server; akses dan nominal tidak berasal dari hitungan rekaan UI. |
| HRIS-037 · P2 | EWA: eligibility, limit tersedia, pengajuan dan status sesuai kontrak. | HRIS-008/027/029; kontrak EWA; Mobile + Backend | Batas dan status diverifikasi server; transaksi sensitif tidak memakai retry otomatis yang dapat menggandakan permintaan. |
| HRIS-038 · P2 | Cache offline per akun/company untuk profil, saldo, riwayat dan pengajuan; konektivitas, last-updated, expired cache dan logout cleanup. | HRIS-002/014/016/019/029; Mobile | Offline menampilkan data lama berlabel jelas; cache terenkripsi sesuai sensitivitas; tidak tercampur antar akun. |
| HRIS-039 · P2 | Queue absensi offline, idempotency, resync, conflict/rejected state dan timestamp offline yang diverifikasi server. | HRIS-009/013/038; kontrak offline backend; Mobile + Backend + QA | Ulang kirim tidak membuat record ganda; item tidak ditandai sukses sebelum accepted server; logout dan perubahan company menangani queue secara eksplisit. |

Kontrak offline perlu dibahas dalam HRIS-009 agar model absensi tidak perlu dibongkar ulang. Implementasi HRIS-038/039 dapat dimajukan setelah dependency-nya selesai jika kebutuhan lapangan menjadi prioritas; tidak perlu menunggu loan/EWA secara teknis.

## 8. Kelengkapan ESS lainnya

Kelompok berikut berprioritas P2 setelah transaksi harian stabil. Setiap subtask ditutup secara terpisah; tersedianya satu layar tidak menutup seluruh kelompok.

### HRIS-040 — P2: profil karyawan, aset, sertifikasi dan organisasi

**Dependency:** HRIS-008/015/021/022/029 dan kontrak tiap modul. **Owner:** Mobile + Backend.

- [ ] HRIS-040a: aset yang ditugaskan kepada employee; hapus deskripsi perangkat contoh.
- [ ] HRIS-040b: sertifikasi nyata, masa berlaku dan dokumen; hapus jumlah sertifikat contoh.
- [ ] HRIS-040c: direktori employee dengan pencarian/pagination dan scope data yang boleh ditampilkan.
- [ ] HRIS-040d: organization chart dan detail employee yang diizinkan.
- [ ] HRIS-040e: onboarding checklist, status dan aksi yang didukung server.

**Selesai per subtask jika:** data sesuai employee/scope, menu dapat dipakai, error/empty/pagination ditangani, dan akses ditolak server jika tidak berizin.

### HRIS-041 — P2: performance, training dan daily activity

**Dependency:** HRIS-015/021/022/029 dan kontrak masing-masing modul. **Owner:** Mobile + Backend.

- [ ] HRIS-041a: performance assignments, goals, self-review dan results pribadi.
- [ ] HRIS-041b: katalog training, enrollment dan status pembelajaran yang tersedia di backend.
- [ ] HRIS-041c: daily activity list/create/detail sesuai workflow backend.

**Selesai per subtask jika:** data dan aksi persisten di server; rules status/permission diterapkan; UI tidak menyediakan aksi yang backend belum dukung.

## 9. Tutup blocker produksi, lalu kualitas dan rilis

| ID / prioritas | Cakupan task | Dependency / owner | Kriteria selesai |
|---|---|---|---|
| HRIS-042 · P0 | Certificate pinning produksi sesuai requirement checklist, strategi rotasi/backup pin dan penanganan kegagalan. Finalisasi inventaris data, privacy URL dan kebutuhan deklarasi store. | HRIS-006; sertifikat/domain final, kebijakan organisasi; Mobile + Infra + Product | Pin valid/invalid/rotasi diuji; privacy URL tersedia dan sesuai penggunaan lokasi/kamera/employee; konfigurasi distribusi tidak melewati proteksi. |
| HRIS-043 · P3 | Lengkapi i18n seluruh layar, format uang/tanggal/timezone, spacing/radius/typography, font bundled, dead theme, launcher/splash resmi dan menu yang tersisa. | Gate P0, HRIS-015/022; aset brand final; Mobile + Design | Tidak ada string bisnis hardcode lintas locale atau menu tanpa aksi; tampilan light/dark konsisten; first launch tanpa internet tidak bergantung download font. |
| HRIS-044 · P3 | UX harian: quick actions berfungsi, shift/countdown/reminder kontrak jika API tersedia, grafik/heatmap/filter/export, haptic, tap tab aktif/hold, accessibility dan text scaling. | HRIS-014/016/017/022/043; Mobile + Design + QA | Setiap aksi memiliki tujuan/hasil nyata; pembesaran teks, screen reader, safe inset dan tap target diuji; transisi tidak menyembunyikan loading/error. |
| HRIS-045 · P4 | Crash reporting dan analytics minimal dengan redaction; force-update dari kontrak version policy; review dependency dan ukuran artefak. | HRIS-006/024; config layanan/version endpoint; Mobile + Infra | Error dapat ditelusuri tanpa isi sensitif; minimum version bekerja; dependency tanpa kebutuhan jelas dihapus; ukuran diukur per ABI/App Bundle. |
| HRIS-046 · P4 | Flavor dev/staging/prod, ID organisasi, signing distribusi Android/iOS, CI build release dan artefak beta. | HRIS-006/007/042; app ID, signing, macOS runner; Mobile + DevOps | Build terpisah per environment; release tidak debug-signed; Android/iOS CI lulus; tidak memakai development proxy/config; distribusi menunggu otorisasi publikasi. |
| HRIS-047 · P4 | Regression dan acceptance rilis: test integrasi API, perangkat Android/iOS, golden light/dark, security/session, offline, push dan alur employee/manager. | Semua task dalam scope rilis; QA + Mobile + Backend | Bukti uji tercatat, blocker ditutup, kontrak dokumentasi sesuai implementasi; keputusan fitur rilis disepakati sebelum beta/publikasi. |

**Gate P0 sebelum HRIS-043/044:** Gate A/B/C serta HRIS-013, HRIS-024/025, HRIS-028/029 dan HRIS-042 selesai. Penutupan gate tetap memerlukan bukti pengujian, bukan hanya keberadaan kode. Penyiapan app ID, privacy dan signing dapat dimulai sejak tahap pertama karena memerlukan input organisasi.

Jika rilis dilakukan bertahap, pengurangan fitur harus diputuskan secara eksplisit. Item di checklist tidak otomatis dianggap dikeluarkan dari scope hanya karena ditempatkan lebih akhir.

## 10. Format pelacakan dan Definition of Done

Untuk setiap task, catat:

| Field | Isi |
|---|---|
| ID dan judul | Gunakan `HRIS-xxx`, termasuk suffix untuk subtask |
| Status | TODO / IN PROGRESS / BLOCKED / REVIEW / DONE |
| Owner aktual | Engineer atau tim yang ditunjuk |
| Dependency/blocker | ID task atau kontrak/input eksternal yang spesifik |
| Bukti implementasi | PR/commit dan file yang berubah |
| Bukti verifikasi | Test, respons tersanitasi, atau hasil uji perangkat yang relevan |
| Sisa pekerjaan | Tidak boleh disembunyikan di balik status DONE |

Task aplikasi dinyatakan DONE bila acceptance task terpenuhi, analyzer/test yang relevan lulus, dan dokumentasi kontrak diperbarui jika berubah. Untuk integrasi endpoint, sertakan bukti respons nyata dari environment uji serta handling sukses, kosong, validasi, unauthorized/forbidden dan gangguan jaringan yang relevan. Test fake saja tidak menutup integrasi backend.

Test regresi dibuat bersama perbaikan berisiko: isolasi akun, rotasi token, duplikasi absensi, scope data, transaksi approval dan queue offline. Jangan menunda semuanya ke HRIS-047. Pengukuran coverage dipakai untuk menemukan bagian belum diuji, bukan menggantikan acceptance bisnis.

## 11. Titik mulai development

HRIS-001 sampai HRIS-012 sudah diselaraskan secara lokal dengan kontrak final
mobile Bearer dan endpoint absensi self-service. Verifikasi deployment,
geofence/face/liveness, replay/idempotency, serta smoke test perangkat masih
menjadi **HRIS-013**. Setelah itu lanjutkan **HRIS-014** untuk riwayat dan
timezone absensi; path riwayat sudah diketahui tetapi response schema belum
disediakan.

Urutan ini mengatasi masalah paling berisiko terlebih dahulu: data akun tertukar, token hasil refresh rusak, dan absensi yang tampak berhasil tetapi tidak tercatat.
