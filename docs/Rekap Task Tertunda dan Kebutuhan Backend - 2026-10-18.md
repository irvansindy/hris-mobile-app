# Rekap Task Tertunda dan Kebutuhan Backend HRIS Mobile

Tanggal rekap: 18 Oktober 2026.
Ditujukan kepada: Backend Developer, Mobile Developer, QA, DevOps, dan Product.

Rekap keseluruhan terbaru dengan status yang bisa difilter ada di
[Rekap Seluruh Task Belum Selesai 19 Oktober](<Rekap Seluruh Task Belum Selesai - 2026-10-19.md>).
Gunakan rekap tersebut untuk koordinasi lintas tahap; dokumen ini tetap
menyimpan detail kebutuhan backend.

Pembaruan setelah checklist backend Oktober: penyesuaian Flutter untuk gate
password, ID employee, pembeda multi-slip, carry-over, dan tracing sudah
diimplementasikan secara lokal. Detail status dan pengujian ada pada
[Matriks Migrasi Oktober](<Migrasi API Oktober 2026 - Matriks dan Report.md>).
Acceptance live tetap terbuka. Path daftar payslip belum terkonfirmasi;
pengguna sudah menyetujui penundaan helpdesk, feed/kudos, dan timesheet dari
rilis awal pada 19 Oktober 2026. Keputusan scope poin 7 selesai, implementasi
ketiganya `DEFERRED` setelah rilis awal. Blocker izin/upload/dokumen/HTTPS tidak
otomatis selesai hanya karena checklist baru sudah diterima.

Pembaruan 19 Oktober: akun manager berhasil pada smoke GET, termasuk today
absensi dan saldo carry-over. Login employee awal 401, lalu berhasil 200 setelah
pengguna memperbarui kredensial lokal; GET today, payslip, cuti, saldo, dan
notifikasi juga 200, logout 200. Employee approval mendapat 403; fixture pending
manager/aset masih kosong dan multi-slip live belum terbukti. Lihat
[report integrasi terbaru](<Verifikasi Integrasi Pasca Migrasi API - 2026-10-19.md>)
sebelum memakai status historis pada bagian berikut.

## 1. Ringkasan kondisi

Untuk filtering tindak lanjut perubahan Oktober, gunakan
[Pending Task Migrasi API Oktober 2026](<Pending Task Migrasi API Oktober 2026.md>).
Nomor poin mengikuti breakdown revisi 1–7 yang sama. Daftar tersebut tidak
menggantikan blocker go-live lain dalam rekap ini.

Sebagian besar implementasi Flutter sudah selesai dan diuji secara lokal.
Pekerjaan yang tersisa mencakup kontrak API yang belum pasti, fitur yang masih
dibatasi, positive live test, konfigurasi release, UAT, dan rollout.

Setelah migrasi API Oktober, suite lokal terbaru lulus 653 tes dan analyzer
bersih. Build APK development sebelumnya sudah berhasil; status build migrasi
terbaru dicatat pada matriks Oktober. Hasil lokal ini bukan pengujian ulang
server/perangkat nyata. Remote CI, acceptance live, dan kesiapan go-live belum
dinyatakan lulus.

Dokumen ini membedakan tiga status:

- Belum lengkap: masih membutuhkan implementasi atau keputusan kontrak.
- Tertunda acceptance: kode tersedia dan lulus lokal, tetapi belum terbukti
  bekerja pada server/perangkat nyata.
- Menunggu konfigurasi: membutuhkan akses, identitas aplikasi, sertifikat,
  akun, atau keputusan partner/owner terkait.

Nomor tahap mengikuti breakdown terbaru berbasis Tahap 0 sampai Tahap 10.

## 2. Prioritas backend dan dependency eksternal

P0 harus diselesaikan sebelum release candidate. P1 wajib diselesaikan bila
fiturnya masuk cakupan rilis. Jika fitur dikeluarkan dari rilis, Product perlu
mencatat keputusan dan Mobile perlu membatasi aksesnya secara jelas.

| ID | Prioritas | Kebutuhan | Owner koordinasi | Kriteria selesai |
| --- | --- | --- | --- | --- |
| BE-01 | P0 | HTTPS staging dan production | Backend + DevOps | Base URL dan sertifikat valid, dapat diakses perangkat, tidak membutuhkan pengecualian cleartext untuk release. |
| BE-02 | P0 | Akun dan fixture acceptance | Backend + QA | Employee attendance/payroll aktif, manager berpermission sesuai, serta minimal dua akun/company untuk uji isolasi tersedia. |
| BE-03 | P0 | Kontrak create izin dan upload lampiran | Backend + Mobile | Format tanggal, satuan `duration`, endpoint multipart, batas upload, dan contoh response/error tercantum di OpenAPI. |
| BE-04 | P0 | Konfirmasi kontrak API yang masih terbuka | Backend + Mobile | Status route di luar OpenAPI, error envelope, identity create cuti, pagination, `shiftDate`, dan batas upload diputuskan tertulis. |
| BE-05 | P0 | Kesiapan absensi dan verifikasi wajah server | Backend + QA | Employee memiliki shift, cabang, geofence, metode absensi, dan enrollment wajah yang dikenali server; fixture mismatch/rate-limit/shift malam tersedia. |
| BE-06 | P1 | Download attachment employee terotorisasi | Backend + Mobile | Endpoint download atau document ID disepakati; ownership dan company scope diperiksa server. |
| BE-07 | P1 | Registrasi token dan delivery push backend | Backend + Mobile + DevOps | Register/delete token, account/company scope, rotation, logout, serta payload notification ID teruji end-to-end melalui HTTPS. |
| BE-08 | P1 | Keputusan cakupan chat | Backend + Product | Kontrak tersedia untuk implementasi, atau chat tetap unavailable dan dikeluarkan dari scope rilis. |
| BE-09 | P0 | Kebijakan data dan operasional release | Backend + Product + Security/Legal + DevOps | Consent, retensi/penghapusan, privacy policy, monitoring, dan rollback memiliki owner serta keputusan tertulis. |
| BE-10 | P0 | Konfirmasi path daftar payslip | Backend + Mobile | Tegaskan `/payroll/payslips` atau `/payroll/payslips/my`, alias yang didukung, dan schema self-service. Client sementara mempertahankan path OpenAPI lama. |
| BE-11 | P1 | Label jenis payslip | Backend + Product + Mobile | Putuskan kebutuhan `runType` self-service. Keputusan scope helpdesk/feed/timesheet sudah selesai: ditunda dari rilis awal atas persetujuan pengguna. |

## 3. Detail pekerjaan API dan fitur

### 3.1 Create izin production

Status: belum lengkap, menunggu kontrak backend.

- [ ] Pastikan format `startDate` dan `endDate`, termasuk aturan timezone.
- [ ] Tetapkan satuan dan aturan validasi `duration` pada
  `POST /permission-requests`.
- [ ] Tentukan operasi upload lampiran, field multipart, response referensi
  file, ukuran maksimum, dan format file yang diperbolehkan.
- [ ] Sediakan contoh sukses, validation error, forbidden, dan konflik status.
- [ ] Mobile menyesuaikan form/data source dan menambahkan contract test.
- [ ] QA menjalankan create, detail, history, dan cancel terhadap server.

Saat ini create izin production sengaja unavailable. History, detail, dan
cancel sudah memiliki implementasi lokal; bukan berarti create sudah selesai.

### 3.2 Finalisasi kontrak lainnya

Status: menunggu konfirmasi backend dan pembaruan matriks bersama.

- [ ] Putuskan dukungan route client yang pada baseline berada di luar OpenAPI
  mobile, terutama area ESS, aktivitas, dan perjalanan/klaim.
- [ ] Selaraskan schema error ketika field `code` tidak dikirim. Flutter sudah
  menerima `code` nullable; keputusan kontrak server tetap perlu didokumentasikan.
- [ ] Konfirmasi identity create cuti. Flutter saat ini mengambil `employeeId`
  dan `companyId` dari sesi aktif untuk memenuhi kontrak yang ada.
- [ ] Konfirmasi format `shiftDate`, pagination, response mutation, dan batas
  ukuran/format upload per endpoint.
- [ ] Perbarui OpenAPI, contoh request/response yang disanitasi, dan matriks
  endpoint berdasarkan keputusan tersebut.

Catatan: referensi receipt claim sudah memakai `data.url` dalam implementasi
Flutter terbaru. Mismatch lama `filePath` tidak perlu dikerjakan ulang;
positive live test receipt tetap diperlukan.

### 3.3 Dokumen employee dan chat

- [ ] Backend menyediakan kontrak download attachment employee yang
  terotorisasi, atau memutuskan penggunaan document-management ID.
- [ ] Mobile mengintegrasikan download setelah kontrak tersedia.
- [ ] QA menguji dokumen kosong, 403, dokumen milik employee/company lain,
  dan pergantian sesi.
- [ ] Backend/Product memutuskan kontrak atau pengecualian scope chat.

Profil saat ini hanya menampilkan metadata attachment yang aman. Aplikasi
tidak membuka `/uploads/*` langsung. Chat belum memiliki kontrak dan tidak
menampilkan data production palsu.

## 4. Acceptance fitur terhadap server dan perangkat

Implementasi area di bawah sudah tersedia secara lokal, kecuali blocker yang
disebutkan sebelumnya. Seluruh kotak berikut masih membutuhkan bukti live.

### 4.1 Absensi dan wajah production, Tahap 2

Owner: Backend + Mobile + QA.

- [ ] Check-in dan check-out Android/iOS menghasilkan satu record di server.
- [ ] Record konsisten pada `/attendance/me/today` dan `/attendance/me`.
- [ ] Restart aplikasi sesudah check-in tetap menampilkan eligibility server.
- [ ] Pergantian Wi-Fi/seluler, timeout, double tap, dan replay tidak membuat
  record ganda.
- [ ] Face mismatch, rate limit, fake GPS, dan lokasi di luar geofence ditolak.
- [ ] Shift malam/open checkout maksimal 36 jam berjalan sesuai kontrak.
- [ ] Kamera/lokasi ditolak dan server 5xx menghasilkan recovery yang jujur.

Production mengirim selfie ketika kebijakan check-in mewajibkannya dan
menyerahkan face match kepada backend. Check-out mengikuti kontrak tanpa
payload wajah. Tidak ada antrean absensi offline.

### 4.2 ESS inti dan kalender, Tahap 3

Owner: Backend + Mobile + QA.

- [ ] Cuti: saldo, history, upload/create, detail, dan cancel.
- [ ] Izin: create setelah kontrak selesai, history, detail, dan cancel.
- [ ] Koreksi absensi, termasuk check-out hari berikutnya untuk shift malam.
- [ ] Lembur dan estimasi upah dari server.
- [ ] Holiday `JL`, next shift kosong/lintas bulan, serta create/cancel tukar shift.
- [ ] Permission ditolak, resource sudah diproses, dan isolasi account/company.

### 4.3 Workflow manager dan ESS lanjutan, Tahap 4

Owner: Backend + Mobile + QA.

- [ ] Manager memiliki `workflow:read` dan `workflow:approve` yang sesuai.
- [ ] Fixture pending tersedia untuk approve, reject, escalate, delegation,
  self-approval, stale conflict, dan bulk partial-success.
- [ ] Loan, EWA, daily activity, trip, claim/receipt, asset, dan reporting line
  memiliki happy path serta failure path live.
- [ ] Branch context, permission negatif, attachment, dan isolasi dua company
  diuji pada Android/iOS.

### 4.4 Payroll dan payslip, Tahap 5

Owner: Backend + Mobile + QA/Security.

- [ ] Employee memiliki akses payroll serta fixture payslip approved/disbursed.
- [ ] Set PIN, unlock, lockout, detail, dan PDF berjalan terhadap server.
- [ ] Expiry, background/resume, account switch, dan jaringan buruk diuji.
- [ ] Screenshot/capture, recent-app preview, serta cache internal PDF diperiksa
  pada Android/iOS nyata.
- [ ] Sepakati precision tampilan nominal pecahan; formatter saat ini masih
  membulatkan tampilan rupiah, sementara mapping mempertahankan nilai pecahan.

## 5. Firebase dan push, Tahap 6

Sudah tersedia: adapter Firebase Android development, konfigurasi pribadi,
panel tes Console, cleanup token lokal, dan regression test lifecycle.
Package development sementara adalah `com.example.hrm_app`. Demo tetap dummy.

Belum selesai:

- [x] Smoke test SDK membuat/menghapus token nyata pada emulator Android, 19 Oktober; bukan bukti delivery Console atau registrasi backend.
- [ ] Delivery Firebase Console untuk foreground, background, dan terminated.
- [ ] Register/delete token nyata melalui `/notifications/device-tokens`.
- [ ] Backend memvalidasi account/company scope, idempotency, rotation,
  reinstall, serta logout offline/online tanpa mengikat token lama ke akun baru.
- [ ] Payload server memakai ID notifikasi/resource stabil, bukan URL route
  arbitrer; isi lock screen tidak membocorkan informasi HR sensitif.
- [ ] Deep link, duplicate event, resource hilang/forbidden, dan pergantian akun
  diuji dengan delivery nyata.
- [ ] Firebase resmi per environment dan iOS/APNs disiapkan.

Mode Firebase development saat ini hanya untuk tes Console. Token tidak
dikirim ke API HRIS, baik HTTP maupun HTTPS, sampai integrasi backend diaktifkan
secara terpisah. Aktivasi Cloud Messaging API saja belum membuktikan delivery.

Konflik cleanup token legacy dengan coordinator sudah diperbaiki. Checklist
lama yang masih menyebut perbaikan itu sebagai pekerjaan baru perlu diperbarui.

## 6. Quality, security, dan performance, Tahap 7

Owner: Mobile + QA + DevOps + Security; kebijakan server melibatkan Backend/Product.

- [ ] Rapikan perubahan integrasi dan tinjau artefak golden failure sebelum
  commit final; jangan memasukkannya sebagai baseline tanpa review.
- [ ] Jalankan remote CI pada commit final dari clean checkout dan simpan run URL.
- [ ] Validasi dependency resolution, native build, permission, lifecycle, dan
  sensitive screen iOS melalui macOS/CI dan perangkat.
- [ ] Audit dependency native Gradle/Swift/CocoaPods, bukan hanya package Pub.
- [ ] Selesaikan warning KGP `firebase_core` dan tetapkan SDK release yang didukung.
- [ ] Uji Android backup/transfer dan kebijakan Keychain device-only/migrasi iOS.
- [ ] Ukur startup, jank, memori, ukuran APK/AAB/IPA, serta baterai kamera/GPS
  pada perangkat kelas target dengan threshold yang disepakati.
- [ ] Finalisasi consent biometrik/lokasi/selfie, retensi/penghapusan server,
  privacy policy, Google Play Data Safety, dan Apple App Privacy.

Pembaruan 19 Oktober: emulator sudah berhasil dijalankan dan smoke SDK token
lulus. Hambatan disk pada laporan sebelumnya merupakan riwayat pengujian,
bukan blocker SDK yang masih aktif. Delivery Console/backend tetap belum
terverifikasi; lihat laporan integrasi terbaru.

## 7. Konfigurasi staging/production, Tahap 8

Owner: Backend + DevOps + Mobile + partner pemilik aplikasi.

- [ ] Sediakan HTTPS staging/production dan pemisahan konfigurasi environment.
- [ ] Tetapkan application ID Android dan bundle ID iOS final.
- [ ] Buat flavor demo/staging/production dengan konfigurasi eksplisit.
- [ ] Siapkan Firebase per environment dan APNs.
- [ ] Siapkan Android upload/app signing serta Apple Team ID, certificate,
  provisioning profile, dan entitlement yang diperlukan.
- [ ] Finalisasi nama aplikasi, icon/splash, versioning, support contact, dan
  deklarasi privasi platform.
- [ ] Lengkapi guard untuk HTTP, example app ID, debug signing, demo repository,
  serta Firebase yang tidak sesuai environment.
- [ ] Distribusikan signed staging build Android/iOS melalui jalur internal.

Guard HTTP/demo dan pembatasan Firebase pribadi sudah ada sebagian. Ini belum
berarti seluruh release guard selesai. APK development dengan signing debug
bukan artifact distribusi production.

## 8. UAT, release candidate, rollout, Tahap 9 dan 10

Owner: QA + Product + Backend + Mobile + DevOps/Security.

- [ ] Jalankan smoke endpoint hingga tidak ada failed maupun blocked.
- [ ] Cocokkan live `/meta/endpoints` dengan OpenAPI dan matriks client terbaru.
- [ ] Uji employee, manager, HR/admin sesuai scope rilis dan minimal dua company.
- [ ] Uji E2E auth, absensi, ESS, approval, payroll, push, logout, dan recovery.
- [ ] Uji upgrade, fresh install, reinstall, koneksi buruk/offline, session expiry,
  maintenance, dan server 5xx.
- [ ] Simpan bukti UAT dan persetujuan Product/QA/Security, lalu freeze RC.
- [ ] Verifikasi backup, migration/backend readiness, feature flag/kill switch,
  serta prosedur rollback aplikasi dan server.
- [ ] Lakukan rollout internal, pilot, lalu bertahap berdasarkan telemetry.
- [ ] Pantau crash, login/refresh, API 4xx/5xx/latency, absensi, push, dan workflow.
- [ ] Jalankan hypercare dan tutup incident serta known issue sesuai kesepakatan.

## 9. Backlog Face ID lokal, terpisah dari jalur production server

Demo multi-angle saat ini menyimpan metadata deteksi terenkripsi per
employee/company/perangkat. Hasilnya bukan embedding, identity match, ataupun
bukti liveness setara Face ID iOS.

Jika pengenalan wajah on-device tetap masuk scope, pekerjaan berikut masih terbuka:

- [ ] Sediakan model beserta lisensi, preprocessing/alignment, tensor input/output,
  dimensi embedding, dan versi model.
- [ ] Implementasikan inference/embedding dan enrollment template nyata.
- [ ] Kalibrasi threshold similarity serta konsistensi enrollment dengan dataset uji.
- [ ] Tetapkan threat model dan implementasikan liveness yang diuji terhadap
  foto, video, serta replay layar.
- [ ] Validasi blur/pencahayaan, penyimpanan template, migrasi, dan recovery.
- [ ] Sepakati integrasi backend/device binding bila dibutuhkan.

Backlog ini tidak otomatis menjadi prasyarat tambahan jalur production yang
menyerahkan face match ke server. Backend/Product perlu mengonfirmasi scope
agar kedua pendekatan tidak tercampur.

## 10. Urutan koordinasi dan bukti penutupan

1. Backend/DevOps menutup HTTPS, kontrak izin/API, serta kesiapan akun dan fixture.
2. Mobile/QA menjalankan Firebase development dan acceptance fitur live.
3. Tim menutup temuan, quality/security, dan konfigurasi signed staging.
4. QA/Product menjalankan UAT dan menyetujui release candidate.
5. DevOps/Backend/Mobile melakukan rollout bertahap dan hypercare.

Konfigurasi release dapat dipersiapkan paralel, tetapi tidak menggantikan
acceptance fitur. Setiap item yang ditutup perlu tanggal, owner, versi kontrak,
commit/build, platform/perangkat, hasil aktual, dan bukti yang disanitasi.

Mohon backend mengembalikan status per ID BE-01 sampai BE-11, PIC, target
penyelesaian, serta tautan kontrak/contoh response atau lokasi fixture.
Credential akun uji disampaikan melalui kanal aman, bukan di dokumen ini.
Jangan menyertakan password, token, PIN, private key, selfie, template wajah,
atau koordinat presisi dalam laporan.

## Referensi internal

- [Breakdown go-live](<Breakdown Task Go Live HRIS Mobile App.md>)
- [Baseline dan matriks kontrak](<Tahap 0 Baseline dan Matriks Kontrak API Mobile.md>)
- [Acceptance absensi tertunda](<Tahap 2 Acceptance Live Tertunda.md>)
- [ESS inti](<Tahap 3 Employee Self-Service Inti.md>)
- [Workflow manager dan ESS lanjutan](<Tahap 4 Workflow Manager dan ESS Lanjutan.md>)
- [Payroll dan payslip](<Tahap 5 Payroll dan Payslip Aman.md>)
- [Acceptance push live](<Tahap 6 Acceptance Push Live Tertunda.md>)
- [Firebase Android development](<Firebase Android Development.md>)
- [Quality dan release gate tertunda](<Tahap 7 Acceptance Release Gate Tertunda.md>)
- [Status Face ID lokal](face-id/implementation-status.md)

Laporan lama tetap menjadi catatan historis. Untuk area yang sudah berubah,
gunakan laporan tahap terbaru dan rekap ini agar pekerjaan selesai tidak
dihitung ulang sebagai pekerjaan yang belum diimplementasikan.
